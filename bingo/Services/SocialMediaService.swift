import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class SocialMediaService: ObservableObject {
    static let shared = SocialMediaService()
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - Posts
    
    func createPost(content: String, imageData: Data?, completion: @escaping (Result<Void, Error>) -> Void) {
        guard Auth.auth().currentUser != nil else {
            completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı giriş yapmamış"])))
            return
        }
        
        let postRef = db.collection("posts").document()
        let postId = postRef.documentID
        
        // Geçici olarak resim yükleme özelliğini devre dışı bırakıyoruz
        // Firebase Storage eklenene kadar sadece metin postları destekleniyor
        savePost(postId: postId, content: content, imageURL: nil, completion: completion)
    }
    
    private func savePost(postId: String, content: String, imageURL: String?, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        let post = PostModel(
            authorId: currentUser.uid,
            authorName: currentUser.displayName ?? "Kullanıcı",
            authorProfileImage: currentUser.photoURL?.absoluteString,
            content: content,
            imageURL: imageURL
        )
        
        db.collection("posts").document(postId).setData(post.toDictionary()) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    func fetchPosts(completion: @escaping (Result<[PostModel], Error>) -> Void) {
        db.collection("posts")
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                let posts = documents.compactMap { doc -> PostModel? in
                    PostModel.from(dict: doc.data(), id: doc.documentID)
                }
                
                completion(.success(posts))
            }
    }
    
    func likePost(postId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        let likeRef = db.collection("posts").document(postId).collection("likes").document(currentUser.uid)
        
        likeRef.getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if snapshot?.exists == true {
                // Unlike
                likeRef.delete { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        self.updatePostLikes(postId: postId, increment: -1, completion: completion)
                    }
                }
            } else {
                // Like
                likeRef.setData(["userId": currentUser.uid, "timestamp": Date()]) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        self.updatePostLikes(postId: postId, increment: 1, completion: completion)
                    }
                }
            }
        }
    }
    
    private func updatePostLikes(postId: String, increment: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("posts").document(postId).updateData([
            "likes": FieldValue.increment(Int64(increment))
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Comments
    
    func addComment(postId: String, content: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        let comment = CommentModel(
            postId: postId,
            authorId: currentUser.uid,
            authorName: currentUser.displayName ?? "Kullanıcı",
            authorProfileImage: currentUser.photoURL?.absoluteString,
            content: content
        )
        
        db.collection("posts").document(postId).collection("comments").addDocument(data: comment.toDictionary()) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                // Update comment count
                self.db.collection("posts").document(postId).updateData([
                    "comments": FieldValue.increment(Int64(1))
                ]) { _ in
                    completion(.success(()))
                }
            }
        }
    }
    
    func fetchComments(postId: String, completion: @escaping (Result<[CommentModel], Error>) -> Void) {
        db.collection("posts").document(postId).collection("comments")
            .order(by: "timestamp", descending: false)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                let comments = documents.compactMap { doc -> CommentModel? in
                    CommentModel.from(dict: doc.data(), id: doc.documentID)
                }
                
                completion(.success(comments))
            }
    }
    
    // MARK: - User Profile
    
    func createUserProfile(userProfile: UserProfileModel, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = userProfile.id else { return }
        
        db.collection("users").document(userId).setData(userProfile.toDictionary()) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    func fetchUserProfile(userId: String, completion: @escaping (Result<UserProfileModel?, Error>) -> Void) {
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = snapshot?.data() else {
                completion(.success(nil))
                return
            }
            
            let profile = UserProfileModel.from(dict: data, id: userId)
            completion(.success(profile))
        }
    }
    
        // MARK: - Image Upload
        // Firebase Storage henüz eklenmediği için resim yükleme özelliği geçici olarak devre dışı
        
        // MARK: - Username Validation
        
        func checkUsernameAvailability(username: String, currentUserId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
            print("DEBUG: Username kontrolü başlatılıyor: '\(username)', User ID: '\(currentUserId)'")
            
            // Kullanıcı adı kontrolü - sadece başka kullanıcılar tarafından kullanılıp kullanılmadığını kontrol et
            db.collection("users")
                .whereField("username", isEqualTo: username)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("DEBUG: Username kontrol hatası: \(error.localizedDescription)")
                        print("DEBUG: Hata detayı: \(error)")
                        completion(.failure(error))
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("DEBUG: Username kontrolü başarılı - hiç doküman bulunamadı, kullanıcı adı müsait")
                        completion(.success(true))
                        return
                    }
                    
                    print("DEBUG: Username kontrolü - \(documents.count) doküman bulundu")
                    
                    // Eğer currentUserId boşsa (kayıt ol sırasında), herhangi bir doküman varsa kullanıcı adı alınmış
                    if currentUserId.isEmpty {
                        let isAvailable = documents.isEmpty
                        print("DEBUG: Kayıt ol sırasında username kontrolü sonucu: \(isAvailable ? "müsait" : "alınmış")")
                        completion(.success(isAvailable))
                        return
                    }
                    
                    // Eğer sadece kendi kullanıcı ID'si varsa, kullanıcı adı mevcut (profil düzenleme sırasında)
                    let otherUsers = documents.filter { $0.documentID != currentUserId }
                    let isAvailable = otherUsers.isEmpty
                    print("DEBUG: Profil düzenleme sırasında username kontrolü sonucu: \(isAvailable ? "müsait" : "alınmış")")
                    completion(.success(isAvailable))
                }
        }
        
        func updateUserProfile(userProfile: UserProfileModel, completion: @escaping (Result<Void, Error>) -> Void) {
            guard let userId = userProfile.id else {
                completion(.failure(NSError(domain: "Profile", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı ID bulunamadı"])))
                return
            }
            
            db.collection("users").document(userId).updateData(userProfile.toDictionary()) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
