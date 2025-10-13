import Foundation
import Combine
import FirebaseAuth

class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var fullName = ""
    @Published var username = ""
    @Published var errorMessage = ""
    @Published var infoMessage = ""
    @Published var isLoggedIn = false
    @Published var showVerificationScreen = false
    @Published var isCheckingUsername = false
    @Published var usernameMessage = ""

    // Email ve şifre realtime kontrol
    var emailMessage: String? {
        if email.isEmpty { return nil }
        let regex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: email) ? nil : "Geçersiz email"
    }

    var passwordMessage: String? {
        if password.isEmpty { return nil }
        if password.count < 6 { return "Şifre çok kısa (min 6 karakter)" }
        if password.rangeOfCharacter(from: .uppercaseLetters) == nil { return "En az bir büyük harf" }
        if password.rangeOfCharacter(from: .decimalDigits) == nil { return "En az bir rakam" }
        return "Şifre güçlü ✅"
    }

    // Signup
    func signup() {
        if let emailErr = emailMessage {
            self.errorMessage = emailErr
            return
        }

        if let passwordErr = passwordMessage, passwordErr != "Şifre güçlü ✅" {
            self.errorMessage = passwordErr
            return
        }
        
        // Check username message for errors
        if !usernameMessage.isEmpty && !usernameMessage.contains("✅") {
            self.errorMessage = usernameMessage
            return
        }
        
        if username.isEmpty {
            self.errorMessage = "Kullanıcı adı gerekli"
            return
        }
        
        if fullName.isEmpty {
            self.errorMessage = "Ad ve soyad gerekli"
            return
        }

        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }

                // Email doğrulama linki gönder
                Auth.auth().currentUser?.sendEmailVerification { emailError in
                    DispatchQueue.main.async {
                        if let emailError = emailError {
                            self?.errorMessage = emailError.localizedDescription
                        } else {
                            self?.infoMessage = "Doğrulama linki email adresinize gönderildi. Lütfen mailinizi kontrol edin."
                            self?.showVerificationScreen = true
                        }
                    }
                }
            }
        }
    }

    // Login
    func login() {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }

                guard let user = Auth.auth().currentUser else { return }

                if user.isEmailVerified {
                    self?.isLoggedIn = true
                    self?.errorMessage = ""
                    self?.showVerificationScreen = false
                    // Kullanıcı giriş yaptığında profil oluştur
                    self?.createUserProfileIfNeeded()
                } else {
                    self?.errorMessage = "Email doğrulanmadı. Lütfen mailinizi kontrol edin ve linke tıklayın."
                    self?.showVerificationScreen = true
                }
            }
        }
    }

    private func createUserProfileIfNeeded() {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        // Kullanıcı profili var mı kontrol et
        SocialMediaService.shared.fetchUserProfile(userId: currentUser.uid) { result in
            switch result {
            case .success(let profile):
                if profile == nil {
                    // Profil yoksa oluştur - kayıt ol sırasında girilen bilgileri kullan
                    let email = currentUser.email ?? "kullanici@example.com"
                    let userFullName = self.fullName.isEmpty == false ? self.fullName : "Kullanıcı"
                    let userUsername = self.username.isEmpty == false ? self.username : "kullanici_\(currentUser.uid.prefix(8))"
                    
                    let defaultProfile = UserProfileModel(
                        email: email,
                        username: userUsername,
                        fullName: userFullName,
                        bio: "Bingo Social'da yeni bir yolculuğa başladım! 🎯",
                        profileImageURL: "https://ui-avatars.com/api/?name=\(userFullName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "User")&background=random&color=fff&size=200"
                    )
                    
                    var newProfile = defaultProfile
                    newProfile.id = currentUser.uid
                    
                    SocialMediaService.shared.createUserProfile(userProfile: newProfile) { result in
                        switch result {
                        case .success:
                            print("DEBUG: Varsayılan profil başarıyla oluşturuldu")
                        case .failure(let error):
                            print("DEBUG: Profil oluşturma hatası: \(error.localizedDescription)")
                        }
                    }
                } else {
                    print("DEBUG: Kullanıcı profili zaten mevcut")
                }
            case .failure(let error):
                print("DEBUG: Profil kontrolü hatası: \(error.localizedDescription)")
                
                // Hata durumunda da varsayılan profil oluşturmayı dene
                let email = currentUser.email ?? "kullanici@example.com"
                let userFullName = self.fullName.isEmpty == false ? self.fullName : "Kullanıcı"
                let userUsername = self.username.isEmpty == false ? self.username : "kullanici_\(currentUser.uid.prefix(8))"
                
                let defaultProfile = UserProfileModel(
                    email: email,
                    username: userUsername,
                    fullName: userFullName,
                    bio: "Bingo Social'da yeni bir yolculuğa başladım! 🎯",
                    profileImageURL: "https://ui-avatars.com/api/?name=\(userFullName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "User")&background=random&color=fff&size=200"
                )
                
                var newProfile = defaultProfile
                newProfile.id = currentUser.uid
                
                SocialMediaService.shared.createUserProfile(userProfile: newProfile) { result in
                    switch result {
                    case .success:
                        print("DEBUG: Varsayılan profil başarıyla oluşturuldu (fallback)")
                    case .failure(let error):
                        print("DEBUG: Profil oluşturma hatası (fallback): \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    func logout() {
        do {
            try Auth.auth().signOut()
            self.isLoggedIn = false
            self.showVerificationScreen = false
            self.email = ""
            self.password = ""
            self.fullName = ""
            self.username = ""
            self.errorMessage = ""
            self.infoMessage = ""
            self.isCheckingUsername = false
            self.usernameMessage = ""
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
