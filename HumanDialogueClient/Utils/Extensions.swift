import Foundation

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Date {
    var displayString: String {
        DateFormatter.displayFormatter.string(from: self)
    }

    var fileNameString: String {
        DateFormatter.fileNameFormatter.string(from: self)
    }
}

extension DateFormatter {
    static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static let fileNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
}

extension TimeInterval {
    var formattedDuration: String {
        let totalSeconds = Int(self.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

extension URL {
    var videoMimeType: String {
        switch pathExtension.lowercased() {
        case "mov":
            return "video/quicktime"
        default:
            return "video/mp4"
        }
    }
}
