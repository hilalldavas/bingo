import SwiftUI

struct VerificationPendingView: View {
    @ObservedObject var vm: AuthViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Email Doğrulaması Bekleniyor")
                .font(.title)
                .bold()

            Text("Lütfen mailinize gönderilen linke tıklayarak hesabınızı doğrulayın.")

            Button("Maili Aç") {
                if let url = URL(string: "https://mail.google.com") {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)

            Button("Tekrar Kontrol Et") {
                vm.login() // Login ile email doğrulamasını tekrar kontrol eder
            }
            .buttonStyle(.bordered)

            Button("Çıkış Yap") {
                vm.logout()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
