import SwiftUI

struct SignupView: View {
    @EnvironmentObject var vm: AuthViewModel
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
                    // Ad Soyad
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.white.opacity(0.8))
                        TextField("Ad Soyad", text: $vm.fullName)
                            .autocapitalization(.words)
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(.white.opacity(0.15))
                    .cornerRadius(12)
                    
                    // Kullanıcı Adı
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "at")
                                .foregroundColor(.white.opacity(0.8))
                            TextField("Kullanıcı Adı", text: $vm.username)
                                .autocapitalization(.none)
                                .textFieldStyle(.plain)
                                .foregroundColor(.white)
                                .onChange(of: vm.username) {
                                    checkUsernameAvailability()
                                }
                            
                            if vm.isCheckingUsername {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                        }
                        .padding()
                        .background(.white.opacity(0.15))
                        .cornerRadius(12)
                        
                        // Username validation message
                        if !vm.usernameMessage.isEmpty {
                            Text(vm.usernameMessage)
                                .font(.caption)
                                .foregroundColor(vm.usernameMessage.contains("✅") ? .green : .red)
                                .padding(.horizontal, 8)
                        }
                    }
                    
                    // E-posta
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
                    
                    // Şifre
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
                    // Kayıt olmadan önce son bir kez kontrol et
                    if vm.isCheckingUsername {
                        vm.errorMessage = "Kullanıcı adı kontrol ediliyor, lütfen bekleyin..."
                        return
                    }
                    
                    if vm.usernameMessage.contains("❌") {
                        vm.errorMessage = "Lütfen geçerli bir kullanıcı adı seçin"
                        return
                    }
                    
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
                .disabled(vm.isCheckingUsername || vm.fullName.isEmpty || vm.username.isEmpty || vm.email.isEmpty || vm.password.isEmpty)
                
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
    
    private func checkUsernameAvailability() {
        // Debounce the API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Eğer kullanıcı adı çok kısa veya boşsa mesajı temizle
            if vm.username.count < 3 {
                vm.usernameMessage = ""
                return
            }
            
            // Eğer boşluk varsa hata göster
            if vm.username.contains(" ") {
                vm.usernameMessage = "❌ Kullanıcı adında boşluk olamaz"
                return
            }
            
            // Format kontrolü
            let regex = "^[a-zA-Z0-9._-]+$"
            if !NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: vm.username) {
                vm.usernameMessage = "❌ Sadece harf, rakam, nokta, tire ve alt çizgi kullanılabilir"
                return
            }
            
            // Gerçek zamanlı username kontrolü - EMAİL GÖNDERİLMEDEN ÖNCE
            vm.isCheckingUsername = true
            vm.usernameMessage = "Kontrol ediliyor..."
            
            print("DEBUG: SignUpView - Username kontrolü başlatılıyor: '\(vm.username)'")
            
            SocialMediaService.shared.checkUsernameAvailability(username: vm.username, currentUserId: "") { result in
                DispatchQueue.main.async {
                    vm.isCheckingUsername = false
                    switch result {
                    case .success(let isAvailable):
                        print("DEBUG: SignUpView - Username kontrol sonucu: \(isAvailable)")
                        if isAvailable {
                            vm.usernameMessage = "✅ Bu kullanıcı adı kullanılabilir"
                        } else {
                            vm.usernameMessage = "❌ Bu kullanıcı adı zaten alınmış"
                        }
                    case .failure(let error):
                        print("DEBUG: SignUpView - Username kontrol hatası: \(error.localizedDescription)")
                        print("DEBUG: SignUpView - Hata detayı: \(error)")
                        vm.usernameMessage = "❌ Kontrol edilemedi: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}
