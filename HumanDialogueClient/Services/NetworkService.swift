import Foundation

final class NetworkService {
    struct UploadTrainingResult {
        let uploadID: String
        let modelName: String
        let modelVersion: String
    }

    private struct ModelResponse: Decodable {
        let name: String
        let version: String

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)

            if let stringValue = try? container.decode(String.self, forKey: .version) {
                version = stringValue
            } else if let intValue = try? container.decode(Int.self, forKey: .version) {
                version = String(intValue)
            } else if let doubleValue = try? container.decode(Double.self, forKey: .version) {
                version = String(doubleValue)
            } else {
                version = "unknown"
            }
        }

        private enum CodingKeys: String, CodingKey {
            case name
            case version
        }
    }

    private let session: URLSession
    private var config: ServerConfig

    init(config: ServerConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func updateConfig(_ config: ServerConfig) {
        self.config = config
    }

    func uploadAndTrainVideo(
        fileURL: URL,
        modelName: String,
        onProgress: @escaping @Sendable (_ progress: Double, _ message: String) -> Void
    ) async throws -> UploadTrainingResult {
        guard let baseURL = URL(string: config.baseURL), !config.baseURL.isEmpty else {
            throw URLError(.badURL)
        }

        let fileName = fileURL.lastPathComponent
        let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard fileSize > 0 else {
            throw URLError(.zeroByteResource)
        }

        let uploadID = makeUploadID()
        let chunkSize = 5 * 1024 * 1024
        let totalChunks = Int(ceil(Double(fileSize) / Double(chunkSize)))

        onProgress(0, "开始上传: \(fileName)，共 \(totalChunks) 个分片")

        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer {
            try? fileHandle.close()
        }

        for chunkIndex in 0 ..< totalChunks {
            let offset = UInt64(chunkIndex * chunkSize)
            let currentChunkSize = min(chunkSize, fileSize - (chunkIndex * chunkSize))

            try fileHandle.seek(toOffset: offset)
            guard let chunkData = try fileHandle.read(upToCount: currentChunkSize), !chunkData.isEmpty else {
                throw URLError(.cannotDecodeContentData)
            }

            let chunkURL = try endpointURL(baseURL: baseURL, path: "upload/chunk")
            var chunkRequest = URLRequest(url: chunkURL)
            chunkRequest.httpMethod = "POST"

            let chunkBody = try createMultipartBody(
                fields: [
                    "chunk_index": String(chunkIndex),
                    "total_chunks": String(totalChunks),
                    "upload_id": uploadID
                ],
                fileFieldName: "file",
                fileName: fileName,
                mimeType: fileURL.videoMimeType,
                fileData: chunkData
            )

            chunkRequest.setValue(chunkBody.contentType, forHTTPHeaderField: "Content-Type")
            let (_, chunkResponse) = try await session.upload(for: chunkRequest, from: chunkBody.data)
            try validateHTTPResponse(chunkResponse)

            let progress = Double(chunkIndex + 1) / Double(totalChunks)
            onProgress(progress, "分片 \(chunkIndex + 1)/\(totalChunks) 上传完成")
        }

        let completeURL = try endpointURL(baseURL: baseURL, path: "upload/complete")
        var completeRequest = URLRequest(url: completeURL)
        completeRequest.httpMethod = "POST"

        let completeBody = try createMultipartBody(
            fields: [
                "upload_id": uploadID,
                "filename": fileName
            ]
        )

        completeRequest.setValue(completeBody.contentType, forHTTPHeaderField: "Content-Type")
        let (_, completeResponse) = try await session.upload(for: completeRequest, from: completeBody.data)
        try validateHTTPResponse(completeResponse)
        onProgress(1, "服务器已完成分片合并")

        let modelURL = try endpointURL(
            baseURL: baseURL,
            path: "models/",
            queryItems: [
                URLQueryItem(name: "name", value: modelName),
                URLQueryItem(name: "video_upload_id", value: uploadID)
            ]
        )

        var modelRequest = URLRequest(url: modelURL)
        modelRequest.httpMethod = "POST"

        let (modelData, modelResponse) = try await session.data(for: modelRequest)
        try validateHTTPResponse(modelResponse)

        let decoded = try JSONDecoder().decode(ModelResponse.self, from: modelData)
        onProgress(1, "模型创建成功: \(decoded.name) v\(decoded.version)")

        return UploadTrainingResult(
            uploadID: uploadID,
            modelName: decoded.name,
            modelVersion: decoded.version
        )
    }

    private func makeUploadID() -> String {
        let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        return "upload_\(Int(Date().timeIntervalSince1970 * 1000))_\(suffix.prefix(9))"
    }

    private func endpointURL(baseURL: URL, path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }

        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path

        if components.path.isEmpty || components.path == "/" {
            components.path = "/\(normalizedPath)"
        } else if components.path.hasSuffix("/") {
            components.path += normalizedPath
        } else {
            components.path += "/\(normalizedPath)"
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        return url
    }

    private func validateHTTPResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ..< 300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    private func createMultipartBody(
        fields: [String: String],
        fileFieldName: String? = nil,
        fileName: String? = nil,
        mimeType: String? = nil,
        fileData: Data? = nil
    ) throws -> (data: Data, contentType: String) {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        let lineBreak = "\r\n"

        for (key, value) in fields {
            body.append("--\(boundary)\(lineBreak)")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\(lineBreak)\(lineBreak)")
            body.append("\(value)\(lineBreak)")
        }

        if let fileFieldName,
           let fileName,
           let mimeType,
           let fileData {
            body.append("--\(boundary)\(lineBreak)")
            body.append("Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(fileName)\"\(lineBreak)")
            body.append("Content-Type: \(mimeType)\(lineBreak)\(lineBreak)")
            body.append(fileData)
            body.append(lineBreak)
        }

        body.append("--\(boundary)--\(lineBreak)")

        return (body, "multipart/form-data; boundary=\(boundary)")
    }
}

private extension Data {
    mutating func append(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        append(data)
    }
}
