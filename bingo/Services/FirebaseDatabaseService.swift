import Firebase

class FirebaseDatabaseService {
    
    static let shared = FirebaseDatabaseService()
    private let dbRef = Database.database().reference()
    
    private init() {}
    
    func saveUser(user: UserModel, completion: @escaping (Error?) -> Void) {
        dbRef.child("users").child(user.id).setValue(user.toDictionary()) { error, _ in
            completion(error)
        }
    }
    
    func fetchUsers(completion: @escaping ([UserModel]) -> Void) {
        dbRef.child("users").observeSingleEvent(of: .value) { snapshot in
            var users = [UserModel]()
            guard let childSnapshots = snapshot.children.allObjects as? [DataSnapshot] else {
                completion(users)
                return
            }
            for child in childSnapshots {
                if let dict = child.value as? [String: Any] {
                    if let user = UserModel.from(dict: dict) {
                        users.append(user)
                    }
                }
            }
            completion(users)
        }
    }
}
