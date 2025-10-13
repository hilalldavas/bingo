import Foundation
import FirebaseFirestore

struct PostModel: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    let authorId: String
    let authorName: String
    let authorProfileImage: String?
    let content: String
    let imageURL: String?
    let timestamp: Date
    var likes: Int
    var comments: Int
    var isLikedByUser: Bool
    
    init(authorId: String, authorName: String, authorProfileImage: String? = nil, content: String, imageURL: String? = nil, likes: Int = 0, comments: Int = 0, isLikedByUser: Bool = false) {
        self.authorId = authorId
        self.authorName = authorName
        self.authorProfileImage = authorProfileImage
        self.content = content
        self.imageURL = imageURL
        self.timestamp = Date()
        self.likes = likes
        self.comments = comments
        self.isLikedByUser = isLikedByUser
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "authorId": authorId,
            "authorName": authorName,
            "authorProfileImage": authorProfileImage as Any,
            "content": content,
            "imageURL": imageURL as Any,
            "timestamp": Timestamp(date: timestamp),
            "likes": likes,
            "comments": comments,
            "isLikedByUser": isLikedByUser
        ]
    }
    
    static func from(dict: [String: Any], id: String) -> PostModel? {
        guard let authorId = dict["authorId"] as? String,
              let authorName = dict["authorName"] as? String,
              let content = dict["content"] as? String,
              let timestamp = dict["timestamp"] as? Timestamp else {
            return nil
        }
        
        var post = PostModel(
            authorId: authorId,
            authorName: authorName,
            authorProfileImage: dict["authorProfileImage"] as? String,
            content: content,
            imageURL: dict["imageURL"] as? String,
            likes: dict["likes"] as? Int ?? 0,
            comments: dict["comments"] as? Int ?? 0,
            isLikedByUser: dict["isLikedByUser"] as? Bool ?? false
        )
        post.id = id
        return post
    }
}

