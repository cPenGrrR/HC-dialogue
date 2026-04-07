import Foundation

enum DialogueState: String, CaseIterable, Codable {
    case idle = "待连接"
    case preparing = "准备中"
    case connecting = "连接中"
    case streaming = "实时会话中"
    case ending = "断开中"
    case error = "错误"
}
