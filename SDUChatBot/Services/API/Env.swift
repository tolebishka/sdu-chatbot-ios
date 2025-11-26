import Foundation

enum Env {
    static let baseURL: URL = {
        guard
            let s = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String,
            let url = URL(string: s), url.scheme?.hasPrefix("http") == true, url.host != nil
        else {
            fatalError("❌ BASE_URL is invalid or missing in Info.plist")
        }
        return url
    }()

    static let oauthStartURL = URL(string: Bundle.main.object(forInfoDictionaryKey: "OAUTH_START_URL") as! String)!
    static let urlScheme = Bundle.main.object(forInfoDictionaryKey: "URL_SCHEME") as! String
    static let staticBearer: String? =
        Bundle.main.object(forInfoDictionaryKey: "STATIC_BEARER") as? String

}
