import Foundation

final class FileService {
    private let fileManager = FileManager.default

    private var baseVideosDirectory: URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let directory = documentsURL.appendingPathComponent("RecordedVideos", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        }
        return directory
    }

    func createVideoFileURL(for username: String) -> URL {
        let safeUserFolder = sanitizedFolderName(from: username)
        let userDirectory = baseVideosDirectory.appendingPathComponent(safeUserFolder, isDirectory: true)
        if !fileManager.fileExists(atPath: userDirectory.path) {
            try? fileManager.createDirectory(at: userDirectory, withIntermediateDirectories: true, attributes: nil)
        }

        let fileName = "video_\(Date().fileNameString).mov"
        return userDirectory.appendingPathComponent(fileName)
    }

    func createAudioFileURL(for username: String) -> URL {
        let safeUserFolder = sanitizedFolderName(from: username)
        let userDirectory = baseVideosDirectory.appendingPathComponent(safeUserFolder, isDirectory: true)
        if !fileManager.fileExists(atPath: userDirectory.path) {
            try? fileManager.createDirectory(at: userDirectory, withIntermediateDirectories: true, attributes: nil)
        }

        let fileName = "audio_\(Date().fileNameString).m4a"
        return userDirectory.appendingPathComponent(fileName)
    }

    func listVideos(for username: String) -> [RecordedVideo] {
        let safeUserFolder = sanitizedFolderName(from: username)
        let userDirectory = baseVideosDirectory.appendingPathComponent(safeUserFolder, isDirectory: true)
        if !fileManager.fileExists(atPath: userDirectory.path) {
            return []
        }

        let urls = (try? fileManager.contentsOfDirectory(
            at: userDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return urls
            .filter { ["mov", "mp4"].contains($0.pathExtension.lowercased()) }
            .map { url in
                let values = try? url.resourceValues(forKeys: [.creationDateKey])
                return RecordedVideo(
                    fileName: url.lastPathComponent,
                    fileURL: url,
                    createdAt: values?.creationDate ?? Date(),
                    duration: 0
                )
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func deleteVideo(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }

    private func sanitizedFolderName(from username: String) -> String {
        let pattern = "[^A-Za-z0-9._-]"
        return username.replacingOccurrences(of: pattern, with: "_", options: .regularExpression)
    }
}
