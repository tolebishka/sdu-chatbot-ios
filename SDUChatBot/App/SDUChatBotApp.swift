import SwiftUI

@main
struct SDUChatBotApp: App {
    @StateObject var auth = AuthViewModel()
    
    init() {
        let raw = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String
        print("🧪 Info.plist BASE_URL raw =", raw as Any)

    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ChatView()
//                    .toolbar {
//                        Button("Выйти") {
//                            auth.logout()
//                        }
//                    }
//                if auth.isLoggedIn {
//                    ChatView()
//                        .toolbar {
//                            Button("Выйти") { auth.logout() }
//                        }
//                } else {
//                    LoginView()
//                }
            }
        }
    }
}
