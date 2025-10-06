import Foundation
import Combine
import FirebaseAuth

class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var errorMessage = ""
    @Published var infoMessage = ""
    @Published var isLoggedIn = false
    @Published var showVerificationScreen = false

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
                } else {
                    self?.errorMessage = "Email doğrulanmadı. Lütfen mailinizi kontrol edin ve linke tıklayın."
                    self?.showVerificationScreen = true
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
            self.errorMessage = ""
            self.infoMessage = ""
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
