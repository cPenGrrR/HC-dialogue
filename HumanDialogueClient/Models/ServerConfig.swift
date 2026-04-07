import Foundation

struct ServerConfig: Codable, Equatable {
    var baseURL: String
    var rtcOfferURL: String

    static let `default` = ServerConfig(
        baseURL: Constants.defaultBaseURL,
        rtcOfferURL: Constants.defaultRTCOfferURL
    )

    private enum CodingKeys: String, CodingKey {
        case baseURL
        case rtcOfferURL
    }

    init(baseURL: String, rtcOfferURL: String) {
        self.baseURL = baseURL
        self.rtcOfferURL = rtcOfferURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? Constants.defaultBaseURL
        rtcOfferURL = try container.decodeIfPresent(String.self, forKey: .rtcOfferURL) ?? Constants.defaultRTCOfferURL
    }
}
