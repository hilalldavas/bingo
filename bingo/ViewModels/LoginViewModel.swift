import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

class LoginViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var errorMessage: String = ""
    @Published var isLoggedIn: Bool = false

    private let db = Firestore.firestore()

    func login() {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }

                guard let user = authResult?.user else { return }

                // Firestore'dan email doğrulamasını kontrol et
                self?.db.collection("verificationCodes").document(user.uid).getDocument { snapshot, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self?.errorMessage = error.localizedDescription
                            return
                        }

                        if let data = snapshot?.data(),
                           let isVerified = data["isVerified"] as? Bool,
                           isVerified {
                            self?.isLoggedIn = true
                        } else {
                            self?.errorMessage = "Lütfen email doğrulamasını tamamlayın."
                        }
                    }
                }
            }
        }
    }
}
