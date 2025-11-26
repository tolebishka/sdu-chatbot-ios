import AuthenticationServices
import UIKit

final class AuthCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }.first ?? UIWindow()
    }

    func startGoogleLogin() async throws -> String {
        let authURL = Env.oauthStartURL
        let callbackScheme = Env.urlScheme

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: callbackScheme) { url, error in
                if let error { return continuation.resume(throwing: error) }
                guard let url else { return continuation.resume(throwing: URLError(.badServerResponse)) }

                // ожидаем sduchat://oauth?code=...
                let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
                if let code = comps?.queryItems?.first(where: { $0.name == "code" })?.value {
                    continuation.resume(returning: code)
                } else if let err = comps?.queryItems?.first(where: { $0.name == "error" })?.value {
                    continuation.resume(throwing: NSError(domain: "oauth", code: 1, userInfo: [NSLocalizedDescriptionKey: err]))
                } else {
                    continuation.resume(throwing: URLError(.cannotDecodeContentData))
                }
            }
            session.prefersEphemeralWebBrowserSession = true
            session.presentationContextProvider = self
            session.start()
        }
    }
}
