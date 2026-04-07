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
                script = "window.HCRTC && window.HCRTC.start && window.HCRTC.start();"
            case "stop":
                script = "window.HCRTC && window.HCRTC.stop && window.HCRTC.stop();"
            case "toggleMute":
                script = "window.HCRTC && window.HCRTC.toggleMute && window.HCRTC.toggleMute();"
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
            guard let payload = message.body as? [String: Any] else { return }
            Task { @MainActor in
                self.onEvent(payload)
            }
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
    }
}
