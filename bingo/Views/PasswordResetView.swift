import SwiftUI

struct PasswordResetView: View {
    @EnvironmentObject var vm: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var resetEmail = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Arka plan gradient
                LinearGradient(
                    colors: [.purple.opacity(0.8), .blue.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 25) {
                    // Header
                    VStack(spacing: 15) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                        
                        Text("Şifre Sıfırlama")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Email adresinizi girin, size şifre sıfırlama linki gönderelim")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 20)
                    
                    // Email input
                    VStack(spacing: 18) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.white.opacity(0.8))
                            TextField("E-posta", text: $resetEmail)
                                .autocapitalization(.none)
                                .textFieldStyle(.plain)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(.white.opacity(0.15))
                        .cornerRadius(12)
                    }
                    
                    // Messages
                    if !vm.errorMessage.isEmpty {
                        Text(vm.errorMessage)
                            .foregroundColor(.red)
                            .bold()
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    if !vm.infoMessage.isEmpty {
                        Text(vm.infoMessage)
                            .foregroundColor(.green)
                            .bold()
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Reset button
                    Button {
                        vm.email = resetEmail
                        vm.resetPassword()
                    } label: {
                        HStack {
                            if vm.isPasswordResetLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                                    .scaleEffect(0.8)
                            }
                            Text(vm.isPasswordResetLoading ? "Gönderiliyor..." : "Şifre Sıfırlama Linki Gönder")
                        }
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .foregroundColor(.purple)
                        .shadow(radius: 5)
                    }
                    .disabled(vm.isPasswordResetLoading || resetEmail.isEmpty)
                    .padding(.top, 15)
                    
                    // Cancel button
                    Button {
                        dismiss()
                    } label: {
                        Text("İptal")
                            .foregroundColor(.white.opacity(0.8))
                            .underline()
                    }
                    .padding(.top, 10)
                    
                    Spacer()
                }
                .padding(.horizontal, 30)
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            resetEmail = vm.email
        }
    }
}

#Preview {
    PasswordResetView()
        .environmentObject(AuthViewModel())
}
