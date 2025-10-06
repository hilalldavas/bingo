import SwiftUI

struct HomeView: View {
    @EnvironmentObject var vm: AuthViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Hoşgeldiniz!").font(.largeTitle).bold()

            Button("Çıkış Yap") {
                vm.logout()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
