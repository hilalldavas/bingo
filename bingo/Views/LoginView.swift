import SwiftUI

struct LoginView: View {
    @StateObject private var vm = AuthViewModel()
    @State private var showSignup = false
    
    var body: some View {
        ZStack {
            // Arka plan gradient
            LinearGradient(
                colors: [.purple.opacity(0.8), .blue.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 25) {
                Text("Bingo App 🎯")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.bottom, 40)
                    .shadow(radius: 10)
                
                VStack(spacing: 18) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.white.opacity(0.8))
                        TextField("E-posta", text: $vm.email)
                            .autocapitalization(.none)
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(.white.opacity(0.15))
                    .cornerRadius(12)
                    
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.white.opacity(0.8))
                        SecureField("Şifre", text: $vm.password)
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(.white.opacity(0.15))
                    .cornerRadius(12)
                }
                
                if !vm.errorMessage.isEmpty {
                    Text(vm.errorMessage)
                        .foregroundColor(.red)
                        .bold()
                        .padding(.top, 5)
                }
                
                Button {
                    vm.login()
                } label: {
                    Text("Giriş Yap")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .foregroundColor(.purple)
                        .shadow(radius: 5)
                }
                .padding(.top, 15)
                
                Button {
                    withAnimation(.spring()) {
                        showSignup = true
                    }
                } label: {
                    Text("Hesabın yok mu? Kayıt ol →")
                        .foregroundColor(.white)
                        .underline()
                }
                .padding(.top, 10)
            }
            .padding(.horizontal, 30)
        }
        .fullScreenCover(isPresented: $showSignup) {
            SignupView(showSignup: $showSignup)
        }
    }
}
