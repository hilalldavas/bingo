import Foundation
import FirebaseFirestore

struct MessageModel: Identifiable, Codable {
    @DocumentID var id: String?
    let senderId: String
    let receiverId: String
    let text: String
    let timestamp: Date
    var isRead: Bool
    
    init(senderId: String, receiverId: String, text: String) {
        self.id = nil
        self.senderId = senderId
        self.receiverId = receiverId
        self.text = text
        self.timestamp = Date()
        self.isRead = false
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "senderId": senderId,
            "receiverId": receiverId,
            "text": text,
            "timestamp": Timestamp(date: timestamp),
            "isRead": isRead
        ]
    }
    
    static func from(dict: [String: Any], id: String) -> MessageModel? {
        guard let senderId = dict["senderId"] as? String,
              let receiverId = dict["receiverId"] as? String,
              let text = dict["text"] as? String,
              let timestamp = dict["timestamp"] as? Timestamp else {
            return nil
        }
        
        var message = MessageModel(senderId: senderId, receiverId: receiverId, text: text)
        message.id = id
        message.isRead = dict["isRead"] as? Bool ?? false
        
        return message
    }
}

struct ConversationModel: Identifiable {
    let id: String
    let otherUserId: String
    var otherUserName: String
    var otherUserProfileImage: String?
    var lastMessage: String
    var lastMessageTimestamp: Date
    var unreadCount: Int
}

