import Foundation
import FirebaseFirestore

struct CommentModel: Identifiable, Codable {
    @DocumentID var id: String?
    let postId: String
    let authorId: String
    let authorName: String
    let authorProfileImage: String?
    let content: String
    let timestamp: Date
    
    init(postId: String, authorId: String, authorName: String, authorProfileImage: String? = nil, content: String) {
        self.postId = postId
        self.authorId = authorId
        self.authorName = authorName
        self.authorProfileImage = authorProfileImage
        self.content = content
        self.timestamp = Date()
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "postId": postId,
            "authorId": authorId,
            "authorName": authorName,
            "authorProfileImage": authorProfileImage as Any,
            "content": content,
            "timestamp": Timestamp(date: timestamp)
        ]
    }
    
    static func from(dict: [String: Any], id: String) -> CommentModel? {
        guard let postId = dict["postId"] as? String,
              let authorId = dict["authorId"] as? String,
              let authorName = dict["authorName"] as? String,
              let content = dict["content"] as? String,
              let timestamp = dict["timestamp"] as? Timestamp else {
            return nil
        }
        
        var comment = CommentModel(
            postId: postId,
            authorId: authorId,
            authorName: authorName,
            authorProfileImage: dict["authorProfileImage"] as? String,
            content: content
        )
        comment.id = id
        return comment
    }
}

