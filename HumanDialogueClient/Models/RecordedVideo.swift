import Foundation

struct RecordedVideo: Identifiable, Hashable {
    let id: UUID
    let fileName: String
    let fileURL: URL
    let createdAt: Date
    let duration: TimeInterval

    init(
        id: UUID = UUID(),
        fileName: String,
        fileURL: URL,
        createdAt: Date = Date(),
        duration: TimeInterval = 0
    ) {
        self.id = id
        self.fileName = fileName
        self.fileURL = fileURL
        self.createdAt = createdAt
        self.duration = duration
    }
}
