import Foundation
import FirebaseFirestore

enum NotificationType: String, Codable {
    case like = "like"
    case comment = "comment"
    case follow = "follow"
}

struct NotificationModel: Identifiable, Codable {
    @DocumentID var id: String?
    let type: NotificationType
    let fromUserId: String
    var fromUserName: String
    var fromUserProfileImage: String?
    let postId: String? // like ve comment için
    let timestamp: Date
    var isRead: Bool
    
    init(type: NotificationType, fromUserId: String, fromUserName: String, fromUserProfileImage: String? = nil, postId: String? = nil) {
        self.id = nil
        self.type = type
        self.fromUserId = fromUserId
        self.fromUserName = fromUserName
        self.fromUserProfileImage = fromUserProfileImage
        self.postId = postId
        self.timestamp = Date()
        self.isRead = false
    }
    
    var message: String {
        switch type {
        case .like:
            return "\(fromUserName) gönderini beğendi"
        case .comment:
            return "\(fromUserName) gönderine yorum yaptı"
        case .follow:
            return "\(fromUserName) seni takip etti"
        }
    }
    
    var icon: String {
        switch type {
        case .like: return "heart.fill"
        case .comment: return "message.fill"
        case .follow: return "person.fill.badge.plus"
        }
    }
    
    var iconColor: String {
        switch type {
        case .like: return "red"
        case .comment: return "purple"
        case .follow: return "blue"
        }
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "type": type.rawValue,
            "fromUserId": fromUserId,
            "fromUserName": fromUserName,
            "fromUserProfileImage": fromUserProfileImage as Any,
            "timestamp": Timestamp(date: timestamp),
            "isRead": isRead
        ]
        
        if let postId = postId {
            dict["postId"] = postId
        }
        
        return dict
    }
    
    static func from(dict: [String: Any], id: String) -> NotificationModel? {
        guard let typeString = dict["type"] as? String,
              let type = NotificationType(rawValue: typeString),
              let fromUserId = dict["fromUserId"] as? String,
              let fromUserName = dict["fromUserName"] as? String,
              let timestamp = dict["timestamp"] as? Timestamp else {
            return nil
        }
        
        var notification = NotificationModel(
            type: type,
            fromUserId: fromUserId,
            fromUserName: fromUserName,
            fromUserProfileImage: dict["fromUserProfileImage"] as? String,
            postId: dict["postId"] as? String
        )
        notification.id = id
        notification.isRead = dict["isRead"] as? Bool ?? false
        
        return notification
    }
}

