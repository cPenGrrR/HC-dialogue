import Foundation

final class NetworkService {
    private let session: URLSession
    private var config: ServerConfig

    init(config: ServerConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func updateConfig(_ config: ServerConfig) {
        self.config = config
    }

    func uploadVideo(fileURL: URL) async throws {
        guard let url = URL(string: config.baseURL), !config.baseURL.isEmpty else {
            throw URLError(.badURL)
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: fileURL)
        let body = try createMultipartBody(
            fileData: fileData,
            fileName: fileURL.lastPathComponent,
            mimeType: fileURL.videoMimeType,
            boundary: boundary
        )

        let (_, response) = try await session.upload(for: request, from: body)
        guard let httpResponse = response as? HTTPURLResponse, (200 ..< 300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    private func createMultipartBody(fileData: Data, fileName: String, mimeType: String, boundary: String) throws -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        guard let openingBoundary = "--\(boundary)\(lineBreak)".data(using: .utf8),
              let disposition = "Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\(lineBreak)".data(using: .utf8),
              let contentType = "Content-Type: \(mimeType)\(lineBreak)\(lineBreak)".data(using: .utf8),
              let closingBoundary = "\(lineBreak)--\(boundary)--\(lineBreak)".data(using: .utf8) else {
            throw URLError(.cannotCreateFile)
        }

        body.append(openingBoundary)
        body.append(disposition)
        body.append(contentType)
        body.append(fileData)
        body.append(closingBoundary)
        return body
    }
}
