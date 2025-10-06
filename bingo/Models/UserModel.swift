struct UserModel {
    let id: String
    let name: String
    let email: String
    
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "name": name,
            "email": email
        ]
    }
    
    static func from(dict: [String: Any]) -> UserModel? {
        guard let id = dict["id"] as? String,
              let name = dict["name"] as? String,
              let email = dict["email"] as? String else {
            return nil
        }
        return UserModel(id: id, name: name, email: email)
    }
}
