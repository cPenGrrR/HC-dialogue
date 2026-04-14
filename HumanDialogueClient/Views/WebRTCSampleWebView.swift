import Foundation
import SwiftUI
import WebKit

struct WebRTCSampleWebView: UIViewRepresentable {
    let offerURL: URL
    let command: String
    let commandID: Int
    @Binding var errorMessage: String
    let onEvent: ([String: Any]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(errorMessage: $errorMessage, onEvent: onEvent)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let userContentController = WKUserContentController()
        let offerURLScript = "window.__HC_OFFER_URL__ = \(javaScriptStringLiteral(offerURL.absoluteString));"
        let userScript = WKUserScript(source: offerURLScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        userContentController.addUserScript(userScript)
        userContentController.add(context.coordinator, name: "hcRtc")
        configuration.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        webView.scrollView.isScrollEnabled = true
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        loadBundledPage(in: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let script = "window.__HC_OFFER_URL__ = \(javaScriptStringLiteral(offerURL.absoluteString));"
        uiView.evaluateJavaScript(script)
        context.coordinator.offerURL = offerURL
        context.coordinator.executeCommandIfNeeded(command: command, commandID: commandID)
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "hcRtc")
    }

    private func loadBundledPage(in webView: WKWebView) {
        guard let fileURL = Bundle.main.url(forResource: "index", withExtension: "html") else {
            errorMessage = "未找到内置 WebRTC 页面 index.html"
            return
        }

        webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
    }

    private func javaScriptStringLiteral(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [value], options: []),
              let json = String(data: data, encoding: .utf8),
              json.count >= 2 else {
            return "\"\""
        }

        return String(json.dropFirst().dropLast())
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        @Binding private var errorMessage: String
        private let onEvent: ([String: Any]) -> Void
        weak var webView: WKWebView?
        var offerURL: URL?
        private var lastCommandID = 0

        init(errorMessage: Binding<String>, onEvent: @escaping ([String: Any]) -> Void) {
            _errorMessage = errorMessage
            self.onEvent = onEvent
        }

        func executeCommandIfNeeded(command: String, commandID: Int) {
            guard commandID > lastCommandID else { return }
            lastCommandID = commandID

            let script: String
            switch command {
            case "start":
                script = """
                if (window.HCRTC && window.HCRTC.start) {
                  Promise.resolve(window.HCRTC.start()).catch(error => {
                    window.webkit.messageHandlers.hcRtc.postMessage({
                      event: 'error',
                      message: `会话启动失败: ${error && error.message ? error.message : String(error)}`
                    });
                  });
                }
                """
            case "stop":
                script = """
                if (window.HCRTC && window.HCRTC.stop) {
                  Promise.resolve(window.HCRTC.stop()).catch(error => {
                    window.webkit.messageHandlers.hcRtc.postMessage({
                      event: 'error',
                      message: `会话关闭失败: ${error && error.message ? error.message : String(error)}`
                    });
                  });
                }
                """
            case "toggleMute":
                script = """
                if (window.HCRTC && window.HCRTC.toggleMute) {
                  Promise.resolve(window.HCRTC.toggleMute()).catch(error => {
                    window.webkit.messageHandlers.hcRtc.postMessage({
                      event: 'error',
                      message: `麦克风切换失败: ${error && error.message ? error.message : String(error)}`
                    });
                  });
                }
                """
            default:
                return
            }

            webView?.evaluateJavaScript(script) { _, error in
                guard let error else { return }
                Task { @MainActor in
                    self.errorMessage = error.localizedDescription
                }
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "hcRtc" else { return }
            guard let payload = normalizedDictionary(from: message.body) else { return }

            if let event = payload["event"] as? String, event == "signalOffer" {
                handleSignalOffer(payload)
                return
            }

            Task { @MainActor in
                self.onEvent(payload)
            }
        }

        private func handleSignalOffer(_ payload: [String: Any]) {
            guard let requestID = payload["requestID"] as? Int else { return }
            guard let offerURL else {
                sendSignalResult(
                    requestID: requestID,
                    payload: ["error": "RTC Offer URL 未配置"]
                )
                return
            }

            guard let localDescription = normalizedDictionary(from: payload["localDescription"]) else {
                sendSignalResult(
                    requestID: requestID,
                    payload: ["error": "本地 SDP 数据缺失"]
                )
                return
            }

            guard
                let type = localDescription["type"] as? String,
                !type.isEmpty,
                let sdp = localDescription["sdp"] as? String,
                !sdp.isEmpty
            else {
                sendSignalResult(
                    requestID: requestID,
                    payload: ["error": "本地 SDP 数据不完整"]
                )
                return
            }

            Task {
                do {
                    let answer = try await requestRemoteAnswer(
                        offerURL: offerURL,
                        localDescription: [
                            "type": type,
                            "sdp": sdp
                        ]
                    )
                    await MainActor.run {
                        self.sendSignalResult(requestID: requestID, payload: ["answer": answer])
                    }
                } catch {
                    await MainActor.run {
                        self.sendSignalResult(
                            requestID: requestID,
                            payload: ["error": error.localizedDescription]
                        )
                    }
                }
            }
        }

        private func requestRemoteAnswer(
            offerURL: URL,
            localDescription: [String: Any]
        ) async throws -> [String: Any] {
            let body = try JSONSerialization.data(withJSONObject: localDescription, options: [])
            var request = URLRequest(url: offerURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 10
            request.httpBody = body

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw SignalError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let responseSnippet = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                throw SignalError.httpStatus(httpResponse.statusCode, responseSnippet)
            }

            guard
                let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                throw SignalError.invalidJSON
            }

            return jsonObject
        }

        private func sendSignalResult(requestID: Int, payload: [String: Any]) {
            guard let webView else { return }
            guard let payloadJSON = jsonString(from: payload) else { return }

            let script = "window.HCRTC && window.HCRTC.receiveNativeSignalResult && window.HCRTC.receiveNativeSignalResult(\(requestID), \(payloadJSON));"
            webView.evaluateJavaScript(script) { _, error in
                guard let error else { return }
                Task { @MainActor in
                    self.errorMessage = error.localizedDescription
                }
            }
        }

        private func jsonString(from object: Any) -> String? {
            guard JSONSerialization.isValidJSONObject(object) else { return nil }
            guard let data = try? JSONSerialization.data(withJSONObject: object, options: []) else {
                return nil
            }

            return String(data: data, encoding: .utf8)
        }

        private func normalizedDictionary(from value: Any?) -> [String: Any]? {
            if let dictionary = value as? [String: Any] {
                return dictionary
            }

            if let dictionary = value as? NSDictionary {
                var normalized: [String: Any] = [:]
                for (key, value) in dictionary {
                    guard let key = key as? String else { continue }
                    normalized[key] = value
                }
                return normalized
            }

            return nil
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            errorMessage = error.localizedDescription
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            errorMessage = error.localizedDescription
        }

        func webView(
            _ webView: WKWebView,
            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
            initiatedByFrame frame: WKFrameInfo,
            type: WKMediaCaptureType,
            decisionHandler: @escaping (WKPermissionDecision) -> Void
        ) {
            decisionHandler(.grant)
        }

        private enum SignalError: LocalizedError {
            case invalidResponse
            case httpStatus(Int, String)
            case invalidJSON

            var errorDescription: String? {
                switch self {
                case .invalidResponse:
                    return "RTC 信令返回了无效响应"
                case let .httpStatus(statusCode, responseSnippet):
                    if responseSnippet.isEmpty {
                        return "RTC 信令失败(\(statusCode))"
                    }
                    return "RTC 信令失败(\(statusCode)): \(responseSnippet)"
                case .invalidJSON:
                    return "RTC 信令响应不是有效 JSON"
                }
            }
        }
    }
}
