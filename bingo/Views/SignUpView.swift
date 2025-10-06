import SwiftUI

struct SignupView: View {
    @ObservedObject var vm = AuthViewModel()
    @Binding var showSignup: Bool
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [.blue.opacity(0.8), .purple.opacity(0.8)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
            .ignoresSafeArea()
            
            VStack(spacing: 25) {
                Text("Yeni Hesap Oluştur ✨")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.bottom, 40)
                
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
                    vm.signup()
                } label: {
                    Text("Kayıt Ol")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .foregroundColor(.blue)
                        .shadow(radius: 5)
                }
                .padding(.top, 15)
                
                Button {
                    withAnimation(.spring()) {
                        showSignup = false
                    }
                } label: {
                    Text("Zaten hesabın var mı? Giriş yap →")
                        .foregroundColor(.white)
                        .underline()
                }
                .padding(.top, 10)
            }
            .padding(.horizontal, 30)
        }
    }
}
