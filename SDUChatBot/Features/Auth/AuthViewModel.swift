import SwiftUI
import Combine
@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = APIClient.shared.getToken() != nil
    let coordinator = AuthCoordinator()

    func login() async {
        do {
            let code = try await coordinator.startGoogleLogin()
            let resp = try await APIClient.shared.authGoogle(code: code)
            APIClient.shared.setToken(resp.accessToken)
            isLoggedIn = true
        } catch {
            print("Auth error:", error)
        }
    }

    func logout() {
        APIClient.shared.setToken(nil)
        isLoggedIn = false
    }
}
