import SwiftUI

struct LoginView: View {
    @StateObject var vm = AuthViewModel()
    var body: some View {
        VStack(spacing: 24) {
            Image("sdu_logo").resizable().scaledToFit().frame(height: 120)
            Text("Войти через Google, чтобы задать вопрос про SDU")
                .multilineTextAlignment(.center)
            Button {
                Task { await vm.login() }
            } label: {
                HStack { Image(systemName: "globe"); Text("Продолжить с Google") }
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
