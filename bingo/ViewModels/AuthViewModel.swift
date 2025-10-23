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

        // Önce username kontrolü yap - EMAİL GÖNDERİLMEDEN ÖNCE
        print("DEBUG: Signup - Username kontrolü başlatılıyor: '\(username)'")
        SocialMediaService.shared.checkUsernameAvailability(username: username, currentUserId: "") { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let isAvailable):
                    if isAvailable {
                        print("DEBUG: Signup - Username müsait, kayıt işlemi başlatılıyor")
                        self.performSignup()
                    } else {
                        self.errorMessage = "Bu kullanıcı adı zaten alınmış. Lütfen başka bir kullanıcı adı seçin."
                    }
                case .failure(let error):
                    print("DEBUG: Signup - Username kontrol hatası: \(error.localizedDescription)")
                    // Hata durumunda da kayıt işlemini devam ettir (Firebase kuralları sorunu olabilir)
                    self.performSignup()
                }
            }
        }
    }
    
    private func performSignup() {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                guard let currentUser = Auth.auth().currentUser else {
                    self.errorMessage = "Kullanıcı oluşturulamadı"
                    return
                }
                
                // Önce kullanıcı profilini oluştur (username database'e kaydedilsin)
                let userProfile = UserProfileModel(
                    email: self.email,
                    username: self.username,
                    fullName: self.fullName,
                    bio: "Bingo Social'da yeni bir yolculuğa başladım! 🎯",
                    profileImageURL: "https://ui-avatars.com/api/?name=\(self.fullName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "User")&background=random&color=fff&size=200"
                )
                
                var profile = userProfile
                profile.id = currentUser.uid
                
                print("DEBUG: Signup - Profil oluşturuluyor: \(profile.username)")
                
                // Profili Firestore'a kaydet
                SocialMediaService.shared.createUserProfile(userProfile: profile) { profileResult in
                    DispatchQueue.main.async {
                        switch profileResult {
                        case .success:
                            print("DEBUG: Signup - Profil başarıyla oluşturuldu")
                            
                            // Profil oluşturulduktan sonra email doğrulama linki gönder
                            Auth.auth().currentUser?.sendEmailVerification { emailError in
                                DispatchQueue.main.async {
                                    if let emailError = emailError {
                                        self.errorMessage = emailError.localizedDescription
                                    } else {
                                        self.infoMessage = "Doğrulama linki email adresinize gönderildi. Lütfen mailinizi kontrol edin."
                                        self.showVerificationScreen = true
                                    }
                                }
                            }
                            
                        case .failure(let error):
                            print("DEBUG: Signup - Profil oluşturma hatası: \(error.localizedDescription)")
                            self.errorMessage = "Profil oluşturulamadı: \(error.localizedDescription)"
                            
                            // Profil oluşturulamazsa kullanıcıyı sil
                            currentUser.delete { _ in
                                print("DEBUG: Signup - Kullanıcı silindi (profil oluşturulamadı)")
                            }
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
                    
                    // Eski kullanıcılar için profil yoksa oluştur (backward compatibility)
                    self?.ensureProfileExists()
                } else {
                    self?.errorMessage = "Email doğrulanmadı. Lütfen mailinizi kontrol edin ve linke tıklayın."
                    self?.showVerificationScreen = true
                }
            }
        }
    }

    // Eski kullanıcılar için backward compatibility - profil yoksa varsayılan profil oluştur
    private func ensureProfileExists() {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        SocialMediaService.shared.fetchUserProfile(userId: currentUser.uid) { result in
            switch result {
            case .success(let profile):
                if profile == nil {
                    print("DEBUG: Eski kullanıcı için profil oluşturuluyor...")
                    // Profil yoksa varsayılan profil oluştur
                    let email = currentUser.email ?? "kullanici@example.com"
                    let emailPrefix = email.components(separatedBy: "@").first ?? "kullanici"
                    
                    let defaultProfile = UserProfileModel(
                        email: email,
                        username: "kullanici_\(currentUser.uid.prefix(8))",
                        fullName: emailPrefix.capitalized,
                        bio: "Bingo Social kullanıcısı",
                        profileImageURL: "https://ui-avatars.com/api/?name=\(emailPrefix.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "User")&background=random&color=fff&size=200"
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
