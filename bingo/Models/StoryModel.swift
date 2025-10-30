import Foundation
import FirebaseFirestore

struct StoryModel: Identifiable, Codable {
    @DocumentID var id: String?
    let authorId: String
    var authorName: String
    var authorProfileImage: String?
    let imageURL: String?
    let videoURL: String?
    let timestamp: Date
    var views: [String] // Görüntüleyenlerin user ID'leri
    
    init(authorId: String, authorName: String, authorProfileImage: String? = nil, imageURL: String? = nil, videoURL: String? = nil) {
        self.id = nil
        self.authorId = authorId
        self.authorName = authorName
        self.authorProfileImage = authorProfileImage
        self.imageURL = imageURL
        self.videoURL = videoURL
        self.timestamp = Date()
        self.views = []
    }
    
    /// 24 saatten eski mi kontrol eder
    var isExpired: Bool {
        let hoursPassed = Calendar.current.dateComponents([.hour], from: timestamp, to: Date()).hour ?? 0
        return hoursPassed >= 24
    }
    
    /// Kaç saat önce paylaşıldı
    var hoursAgo: Int {
        Calendar.current.dateComponents([.hour], from: timestamp, to: Date()).hour ?? 0
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "authorId": authorId,
            "authorName": authorName,
            "authorProfileImage": authorProfileImage as Any,
            "imageURL": imageURL as Any,
            "videoURL": videoURL as Any,
            "timestamp": Timestamp(date: timestamp),
            "views": views
        ]
    }
    
    static func from(dict: [String: Any], id: String) -> StoryModel? {
        guard let authorId = dict["authorId"] as? String,
              let authorName = dict["authorName"] as? String,
              let timestamp = dict["timestamp"] as? Timestamp else {
            return nil
        }
        
        var story = StoryModel(
            authorId: authorId,
            authorName: authorName,
            authorProfileImage: dict["authorProfileImage"] as? String,
            imageURL: dict["imageURL"] as? String,
            videoURL: dict["videoURL"] as? String
        )
        story.id = id
        story.views = dict["views"] as? [String] ?? []
        
        return story
    }
}

