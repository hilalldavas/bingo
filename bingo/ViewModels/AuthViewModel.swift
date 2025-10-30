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
    @Published var showPasswordReset = false
    @Published var isPasswordResetLoading = false

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
        // Info mesajını temizle
        self.infoMessage = ""
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    // Silinmiş kullanıcı hatası için özel mesaj
                    let nsError = error as NSError
                    if nsError.code == 17011 { // User not found
                        self?.errorMessage = "Bu hesap silinmiş veya mevcut değil. Lütfen yeni bir hesap oluşturun."
                    } else {
                        self?.errorMessage = error.localizedDescription
                    }
                    return
                }

                guard let user = Auth.auth().currentUser else { return }

                if user.isEmailVerified {
                    // Hesap dondurulmuş mu kontrol et
                    self?.checkAccountStatus(userId: user.uid)
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
    
    // Password Reset
    func resetPassword() {
        guard !email.isEmpty else {
            errorMessage = "Lütfen email adresinizi girin"
            return
        }
        
        guard emailMessage == nil else {
            errorMessage = "Lütfen geçerli bir email adresi girin"
            return
        }
        
        isPasswordResetLoading = true
        errorMessage = ""
        infoMessage = ""
        
        Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
            DispatchQueue.main.async {
                self?.isPasswordResetLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.infoMessage = "Şifre sıfırlama linki \(self?.email ?? "") adresine gönderildi. Lütfen mailinizi kontrol edin."
                    self?.showPasswordReset = false
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
            self.showPasswordReset = false
            self.isPasswordResetLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Account Status Check
    
    /// Hesap durumunu kontrol eder (aktif, dondurulmuş, silinmiş)
    private func checkAccountStatus(userId: String) {
        print("DEBUG: Hesap durumu kontrol ediliyor - UserID: \(userId)")
        
        // Önce 30 gün geçmiş hesapları kontrol et
        SocialMediaService.shared.checkAndDeleteExpiredDeactivatedAccounts(userId: userId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let wasDeleted):
                    if wasDeleted {
                        // Hesap 30 gün geçtiği için silindi
                        print("DEBUG: Hesap 30 gün geçtiği için kalıcı olarak silindi")
                        self.errorMessage = "Hesabınız 30 günden fazla dondurulduğu için kalıcı olarak silindi. Lütfen yeni bir hesap oluşturun."
                        self.logout()
                        return
                    }
                    
                    // Hesap durumunu kontrol et
                    SocialMediaService.shared.fetchUserProfile(userId: userId) { profileResult in
                        DispatchQueue.main.async {
                            switch profileResult {
                            case .success(let profile):
                                if let profile = profile {
                                    if profile.isDeactivated {
                                        // Hesap dondurulmuş - reaktive et
                                        let daysRemaining = self.calculateRemainingDays(from: profile.deactivatedAt)
                                        print("DEBUG: Hesap dondurulmuş, yeniden aktifleştiriliyor. Kalan gün: \(daysRemaining)")
                                        
                                        self.reactivateAccount(userId: userId)
                                    } else {
                                        // Hesap aktif
                                        self.isLoggedIn = true
                                        self.errorMessage = ""
                                        self.showVerificationScreen = false
                                        self.ensureProfileExists()
                                    }
                                } else {
                                    // Profil bulunamadı
                                    self.errorMessage = "Hesabınız sistemden silinmiş. Lütfen tekrar kayıt olun."
                                    self.logout()
                                }
                            case .failure(let error):
                                print("DEBUG: Profil kontrolü hatası: \(error.localizedDescription)")
                                // Hata durumunda yine de giriş yap
                                self.isLoggedIn = true
                                self.ensureProfileExists()
                            }
                        }
                    }
                    
                case .failure(let error):
                    print("DEBUG: Deactivation kontrolü hatası: \(error.localizedDescription)")
                    // Hata durumunda normal login devam etsin
                    self.isLoggedIn = true
                    self.ensureProfileExists()
                }
            }
        }
    }
    
    /// Hesabı yeniden aktifleştirir
    private func reactivateAccount(userId: String) {
        SocialMediaService.shared.reactivateAccount(userId: userId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success:
                    print("DEBUG: Hesap başarıyla yeniden aktifleştirildi")
                    self.isLoggedIn = true
                    self.errorMessage = ""
                    self.infoMessage = "Tekrar hoş geldiniz! Hesabınız yeniden aktifleştirildi."
                    self.showVerificationScreen = false
                case .failure(let error):
                    print("DEBUG: Hesap aktifleştirme hatası: \(error.localizedDescription)")
                    self.errorMessage = "Hesap aktifleştirilemedi: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Dondurulmuş hesap için kalan gün sayısını hesaplar
    private func calculateRemainingDays(from deactivatedAt: Date?) -> Int {
        guard let deactivatedAt = deactivatedAt else { return 30 }
        let daysPassed = Calendar.current.dateComponents([.day], from: deactivatedAt, to: Date()).day ?? 0
        return max(0, 30 - daysPassed)
    }
    
    // MARK: - User Profile Validation
    
    /// Firestore'da kullanıcı profili var mı kontrol eder
    /// Profil silinmişse kullanıcıyı çıkış yapar
    func validateUserProfile() {
        guard let currentUser = Auth.auth().currentUser else {
            print("DEBUG: validateUserProfile - Kullanıcı giriş yapmamış")
            self.isLoggedIn = false
            return
        }
        
        print("DEBUG: validateUserProfile - Profil kontrolü başlatılıyor: \(currentUser.uid)")
        
        SocialMediaService.shared.fetchUserProfile(userId: currentUser.uid) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let profile):
                    if profile == nil {
                        // Profil bulunamadı - kullanıcı veritabanından silinmiş
                        print("DEBUG: validateUserProfile - Profil bulunamadı! Kullanıcı çıkış yapılıyor...")
                        self.errorMessage = "Hesabınız sistemden silinmiş. Lütfen tekrar kayıt olun."
                        self.logout()
                    } else {
                        print("DEBUG: validateUserProfile - Profil mevcut, kullanıcı geçerli")
                    }
                case .failure(let error):
                    print("DEBUG: validateUserProfile - Hata: \(error.localizedDescription)")
                    // Network hatası vs olabilir, kullanıcıyı çıkarmayalım
                    // Sadece kritik hatalarda çıkış yapalım
                }
            }
        }
    }
}
