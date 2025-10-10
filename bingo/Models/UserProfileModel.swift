import Foundation
import FirebaseFirestore

struct UserProfileModel: Identifiable, Codable {
    @DocumentID var id: String?
    let email: String
    var username: String
    var fullName: String
    var bio: String?
    var profileImageURL: String?
    var followers: Int
    var following: Int
    var posts: Int
    let timestamp: Date
    
    init(email: String, username: String, fullName: String, bio: String? = nil, profileImageURL: String? = nil, followers: Int = 0, following: Int = 0, posts: Int = 0) {
        self.id = nil
        self.email = email
        self.username = username
        self.fullName = fullName
        self.bio = bio
        self.profileImageURL = profileImageURL
        self.followers = followers
        self.following = following
        self.posts = posts
        self.timestamp = Date()
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "email": email,
            "username": username,
            "fullName": fullName,
            "bio": bio as Any,
            "profileImageURL": profileImageURL as Any,
            "followers": followers,
            "following": following,
            "posts": posts,
            "timestamp": Timestamp(date: timestamp)
        ]
    }
    
    static func from(dict: [String: Any], id: String) -> UserProfileModel? {
        guard let email = dict["email"] as? String,
              let username = dict["username"] as? String,
              let fullName = dict["fullName"] as? String,
              let timestamp = dict["timestamp"] as? Timestamp else {
            return nil
        }
        
        var profile = UserProfileModel(
            email: email,
            username: username,
            fullName: fullName,
            bio: dict["bio"] as? String,
            profileImageURL: dict["profileImageURL"] as? String,
            followers: dict["followers"] as? Int ?? 0,
            following: dict["following"] as? Int ?? 0,
            posts: dict["posts"] as? Int ?? 0
        )
        profile.id = id
        return profile
    }
}
