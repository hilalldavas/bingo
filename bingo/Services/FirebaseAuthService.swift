import FirebaseAuth
import FirebaseFirestore

class FirebaseAuthService {
    static let shared = FirebaseAuthService()
    private let db = Firestore.firestore()
    private init() {}

    func signUp(email: String, password: String, completion: @escaping (Result<String, Error>) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let user = authResult?.user else { return }

            let code = String(format: "%06d", Int.random(in: 0...999999))

            self.db.collection("verificationCodes").document(user.uid).setData([
                "code": code,
                "email": email,
                "isVerified": false
            ]) { dbError in
                if let dbError = dbError {
                    completion(.failure(dbError))
                } else {
                    completion(.success(code))
                }
            }
        }
    }

    func verifyCode(uid: String, code: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let docRef = db.collection("verificationCodes").document(uid)
        docRef.getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = snapshot?.data(),
                  let correctCode = data["code"] as? String else {
                completion(.success(false))
                return
            }

            if code == correctCode {
                docRef.updateData(["isVerified": true]) { err in
                    if let err = err {
                        completion(.failure(err))
                    } else {
                        completion(.success(true))
                    }
                }
            } else {
                completion(.success(false))
            }
        }
    }

    func login(email: String, password: String, completion: @escaping (Result<String, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let user = authResult?.user else { return }

            self.db.collection("verificationCodes").document(user.uid).getDocument { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                if let data = snapshot?.data(),
                   let isVerified = data["isVerified"] as? Bool,
                   isVerified {
                    completion(.success(user.uid))
                } else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Lütfen email doğrulamasını tamamlayın."])))
                }
            }
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }
}
