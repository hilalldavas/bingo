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
        guard let currentUser = Auth.auth().currentUser else { 
            completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı giriş yapmamış"])))
            return 
        }
        
        print("DEBUG: Post oluşturma - Kullanıcı ID: \(currentUser.uid)")
        print("DEBUG: Kullanıcı email: \(currentUser.email ?? "nil")")
        
        // Basit çözüm: Kullanıcının email'inden isim oluştur
        let authorName: String
        let authorProfileImage: String?
        
        if let email = currentUser.email {
            // Email'den kullanıcı adı oluştur (@ işaretinden önceki kısmı al)
            let emailPrefix = email.components(separatedBy: "@").first ?? "kullanici"
            authorName = emailPrefix.capitalized
            authorProfileImage = "https://ui-avatars.com/api/?name=\(emailPrefix.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "User")&background=random&color=fff&size=200"
        } else {
            authorName = "Kullanıcı"
            authorProfileImage = "https://ui-avatars.com/api/?name=User&background=random&color=fff&size=200"
        }
        
        print("DEBUG: Post için kullanılacak isim: \(authorName)")
        
        let post = PostModel(
            authorId: currentUser.uid,
            authorName: authorName,
            authorProfileImage: authorProfileImage,
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
        guard let currentUser = Auth.auth().currentUser else {
            completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı giriş yapmamış"])))
            return
        }
        
        db.collection("posts")
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .getDocuments { [weak self] snapshot, error in
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
                
                // Check like status for each post
                self?.checkLikeStatusForPosts(posts: posts, userId: currentUser.uid, completion: completion)
            }
    }
    
    private func checkLikeStatusForPosts(posts: [PostModel], userId: String, completion: @escaping (Result<[PostModel], Error>) -> Void) {
        let dispatchGroup = DispatchGroup()
        var updatedPosts = posts
        
        for (index, post) in posts.enumerated() {
            guard let postId = post.id else { continue }
            
            dispatchGroup.enter()
            db.collection("posts").document(postId).collection("likes").document(userId).getDocument { snapshot, error in
                defer { dispatchGroup.leave() }
                
                // Her durumda post'u güncelle - beğenilmişse true, beğenilmemişse false
                let isLiked = snapshot?.exists ?? false
                updatedPosts[index] = PostModel(
                    authorId: post.authorId,
                    authorName: post.authorName,
                    authorProfileImage: post.authorProfileImage,
                    content: post.content,
                    imageURL: post.imageURL,
                    likes: post.likes,
                    comments: post.comments,
                    isLikedByUser: isLiked
                )
                updatedPosts[index].id = postId
                
                print("DEBUG: Post \(postId) - isLiked: \(isLiked)")
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(.success(updatedPosts))
        }
    }
    
    func likePost(postId: String, completion: @escaping (Result<PostModel, Error>) -> Void) {
        guard let currentUser = Auth.auth().currentUser else { 
            completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı giriş yapmamış"])))
            return 
        }
        
        print("DEBUG: likePost çağrıldı - PostID: \(postId), UserID: \(currentUser.uid)")
        let likeRef = db.collection("posts").document(postId).collection("likes").document(currentUser.uid)
        
        likeRef.getDocument { snapshot, error in
            if let error = error {
                print("DEBUG: Like kontrol hatası: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            print("DEBUG: Like durumu - exists: \(snapshot?.exists ?? false)")
            
            if snapshot?.exists == true {
                // Unlike
                print("DEBUG: Unlike işlemi başlatılıyor")
                likeRef.delete { error in
                    if let error = error {
                        print("DEBUG: Unlike hatası: \(error.localizedDescription)")
                        completion(.failure(error))
                    } else {
                        print("DEBUG: Unlike başarılı")
                        self.updatePostLikesAndFetch(postId: postId, increment: -1, currentUserId: currentUser.uid, completion: completion)
                    }
                }
            } else {
                // Like
                print("DEBUG: Like işlemi başlatılıyor")
                likeRef.setData(["userId": currentUser.uid, "timestamp": Date()]) { error in
                    if let error = error {
                        print("DEBUG: Like hatası: \(error.localizedDescription)")
                        completion(.failure(error))
                    } else {
                        print("DEBUG: Like başarılı")
                        self.updatePostLikesAndFetch(postId: postId, increment: 1, currentUserId: currentUser.uid, completion: completion)
                    }
                }
            }
        }
    }
    
    private func updatePostLikesAndFetch(postId: String, increment: Int, currentUserId: String, completion: @escaping (Result<PostModel, Error>) -> Void) {
        print("DEBUG: updatePostLikesAndFetch - PostID: \(postId), Increment: \(increment)")
        
        // Önce beğeni sayısını güncelle
        db.collection("posts").document(postId).updateData([
            "likes": FieldValue.increment(Int64(increment))
        ]) { error in
            if let error = error {
                print("DEBUG: Like count update hatası: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            print("DEBUG: Like count başarıyla güncellendi")
            
            // Sonra güncel post verilerini çek
            self.fetchPost(postId: postId) { result in
                switch result {
                case .success(let post):
                    print("DEBUG: Güncel post verileri çekildi - likes: \(post.likes), isLiked: \(post.isLikedByUser)")
                    completion(.success(post))
                case .failure(let error):
                    print("DEBUG: Post fetch hatası: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func updatePostLikes(postId: String, increment: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        print("DEBUG: updatePostLikes - PostID: \(postId), Increment: \(increment)")
        db.collection("posts").document(postId).updateData([
            "likes": FieldValue.increment(Int64(increment))
        ]) { error in
            if let error = error {
                print("DEBUG: Like count update hatası: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("DEBUG: Like count başarıyla güncellendi")
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Real-time Updates
    
    func observePostChanges(postId: String, completion: @escaping (Result<PostModel, Error>) -> Void) {
        db.collection("posts").document(postId).addSnapshotListener { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = snapshot?.data(),
                  let post = PostModel.from(dict: data, id: postId) else {
                completion(.failure(NSError(domain: "PostNotFound", code: -1, userInfo: [NSLocalizedDescriptionKey: "Post bulunamadı"])))
                return
            }
            
            completion(.success(post))
        }
    }
    
    // MARK: - Comments
    
    func addComment(postId: String, content: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let currentUser = Auth.auth().currentUser else { 
            completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı giriş yapmamış"])))
            return 
        }
        
        print("DEBUG: Yorum ekleme - Kullanıcı ID: \(currentUser.uid)")
        print("DEBUG: Kullanıcı email: \(currentUser.email ?? "nil")")
        print("DEBUG: Kullanıcı displayName: \(currentUser.displayName ?? "nil")")
        
        // Basit çözüm: Kullanıcının email'inden isim oluştur
        let authorName: String
        let authorProfileImage: String?
        
        if let email = currentUser.email {
            // Email'den kullanıcı adı oluştur (@ işaretinden önceki kısmı al)
            let emailPrefix = email.components(separatedBy: "@").first ?? "kullanici"
            authorName = emailPrefix.capitalized
            authorProfileImage = "https://ui-avatars.com/api/?name=\(emailPrefix.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "User")&background=random&color=fff&size=200"
        } else {
            authorName = "Kullanıcı"
            authorProfileImage = "https://ui-avatars.com/api/?name=User&background=random&color=fff&size=200"
        }
        
        print("DEBUG: Kullanılacak isim: \(authorName)")
        
        let comment = CommentModel(
            postId: postId,
            authorId: currentUser.uid,
            authorName: authorName,
            authorProfileImage: authorProfileImage,
            content: content
        )
        
        db.collection("posts").document(postId).collection("comments").addDocument(data: comment.toDictionary()) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                // Update comment count
                self.db.collection("posts").document(postId).updateData([
                    "comments": FieldValue.increment(Int64(1))
                ]) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
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
        guard let userId = userProfile.id else { 
            print("DEBUG: createUserProfile - UserID bulunamadı")
            return 
        }
        
        print("DEBUG: createUserProfile - UserID: \(userId), FullName: \(userProfile.fullName)")
        let profileData = userProfile.toDictionary()
        print("DEBUG: createUserProfile - Profile data: \(profileData)")
        
        db.collection("users").document(userId).setData(profileData) { error in
            if let error = error {
                print("DEBUG: createUserProfile hatası: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("DEBUG: createUserProfile başarılı")
                completion(.success(()))
            }
        }
    }
    
    func fetchUserProfile(userId: String, completion: @escaping (Result<UserProfileModel?, Error>) -> Void) {
        print("DEBUG: fetchUserProfile çağrıldı - UserID: \(userId)")
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                print("DEBUG: fetchUserProfile hatası: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = snapshot?.data() else {
                print("DEBUG: fetchUserProfile - Profil verisi bulunamadı")
                completion(.success(nil))
                return
            }
            
            print("DEBUG: fetchUserProfile - Profil verisi bulundu: \(data)")
            let profile = UserProfileModel.from(dict: data, id: userId)
            print("DEBUG: fetchUserProfile - Parsed profile: \(profile?.fullName ?? "nil")")
            completion(.success(profile))
        }
    }
    
        // MARK: - Image Upload
        // Firebase Storage henüz eklenmediği için resim yükleme özelliği geçici olarak devre dışı
        
        // MARK: - Username Validation
        
        func checkUsernameAvailability(username: String, currentUserId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
            print("DEBUG: Username kontrolü başlatılıyor: '\(username)', User ID: '\(currentUserId)'")
            
            // Format kontrolü
            let regex = "^[a-zA-Z0-9._-]+$"
            if !NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: username) {
                print("DEBUG: Format kontrolü başarısız")
                completion(.success(false))
                return
            }
            
            if username.count < 3 {
                print("DEBUG: Uzunluk kontrolü başarısız")
                completion(.success(false))
                return
            }
            
        // FİREBASE KONTROLÜ - Gerçek benzersizlik kontrolü
        print("DEBUG: Firebase query başlatılıyor - collection: users, field: username, value: \(username)")
        
        db.collection("users")
            .whereField("username", isEqualTo: username)
            .getDocuments { snapshot, error in
                print("DEBUG: Firebase query tamamlandı")
                
                if let error = error {
                    print("DEBUG: Username kontrol hatası: \(error.localizedDescription)")
                    print("DEBUG: Hata detayı: \(error)")
                    print("DEBUG: Error code: \((error as NSError).code)")
                    print("DEBUG: Error domain: \((error as NSError).domain)")
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
            
            db.collection("users").document(userId).updateData(userProfile.toDictionary()) { [weak self] error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    // Update all posts and comments by this user with new profile info
                    self?.updateUserPostsAndComments(userId: userId, userProfile: userProfile) { updateError in
                        if let updateError = updateError {
                            print("DEBUG: Error updating user posts/comments: \(updateError.localizedDescription)")
                        }
                        completion(.success(()))
                    }
                }
            }
        }
        
        private func updateUserPostsAndComments(userId: String, userProfile: UserProfileModel, completion: @escaping (Result<Void, Error>) -> Void) {
            let batch = db.batch()
            let dispatchGroup = DispatchGroup()
            var hasUpdates = false
            
            // Update posts
            dispatchGroup.enter()
            db.collection("posts").whereField("authorId", isEqualTo: userId).getDocuments { snapshot, error in
                defer { dispatchGroup.leave() }
                
                if let documents = snapshot?.documents {
                    for document in documents {
                        let postRef = db.collection("posts").document(document.documentID)
                        batch.updateData([
                            "authorName": userProfile.fullName,
                            "authorProfileImage": userProfile.profileImageURL as Any
                        ], forDocument: postRef)
                        hasUpdates = true
                    }
                }
            }
            
            // Update comments
            dispatchGroup.enter()
            db.collectionGroup("comments").whereField("authorId", isEqualTo: userId).getDocuments { snapshot, error in
                defer { dispatchGroup.leave() }
                
                if let documents = snapshot?.documents {
                    for document in documents {
                        let commentRef = document.reference
                        batch.updateData([
                            "authorName": userProfile.fullName,
                            "authorProfileImage": userProfile.profileImageURL as Any
                        ], forDocument: commentRef)
                        hasUpdates = true
                    }
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                if hasUpdates {
                    batch.commit { error in
                        if let error = error {
                            completion(.failure(error))
                        } else {
                            completion(.success(()))
                        }
                    }
                } else {
                    completion(.success(()))
                }
            }
        }
        
        // MARK: - Helper Methods
        
        func ensureUserProfileExists(userId: String, completion: @escaping (Result<UserProfileModel?, Error>) -> Void) {
            fetchUserProfile(userId: userId) { [weak self] result in
                switch result {
                case .success(let profile):
                    if let profile = profile {
                        completion(.success(profile))
                    } else {
                        // Create default profile
                        guard let currentUser = Auth.auth().currentUser else {
                            completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı giriş yapmamış"])))
                            return
                        }
                        
                        let email = currentUser.email ?? "kullanici@example.com"
                        let defaultProfile = UserProfileModel(
                            email: email,
                            username: "kullanici_\(userId.prefix(8))",
                            fullName: "Kullanıcı",
                            bio: "Bingo Social kullanıcısı",
                            profileImageURL: "https://ui-avatars.com/api/?name=User&background=random&color=fff&size=200"
                        )
                        var newProfile = defaultProfile
                        newProfile.id = userId
                        
                        self?.createUserProfile(userProfile: newProfile) { createResult in
                            switch createResult {
                            case .success:
                                completion(.success(newProfile))
                            case .failure(let error):
                                completion(.failure(error))
                            }
                        }
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
        
        private func updateUserPostCount(userId: String, increment: Int, completion: @escaping (Result<Void, Error>) -> Void) {
            db.collection("users").document(userId).updateData([
                "posts": FieldValue.increment(Int64(increment))
            ]) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
        
        // MARK: - Single Post Operations
        
        func deletePost(postId: String, completion: @escaping (Result<Void, Error>) -> Void) {
            guard let currentUser = Auth.auth().currentUser else {
                completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı giriş yapmamış"])))
                return
            }
            
            // First get the post to verify ownership
            db.collection("posts").document(postId).getDocument { [weak self] snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = snapshot?.data(),
                      let authorId = data["authorId"] as? String,
                      authorId == currentUser.uid else {
                    completion(.failure(NSError(domain: "Permission", code: -1, userInfo: [NSLocalizedDescriptionKey: "Bu postu silme yetkiniz yok"])))
                    return
                }
                
                // Delete the post
                self?.db.collection("posts").document(postId).delete { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        // Update user's post count
                        self?.updateUserPostCount(userId: currentUser.uid, increment: -1) { _ in
                            completion(.success(()))
                        }
                    }
                }
            }
        }
        
        func fetchPost(postId: String, completion: @escaping (Result<PostModel?, Error>) -> Void) {
            guard let currentUser = Auth.auth().currentUser else {
                completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı giriş yapmamış"])))
                return
            }
            
            db.collection("posts").document(postId).getDocument { [weak self] snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = snapshot?.data(), let post = PostModel.from(dict: data, id: postId) else {
                    completion(.success(nil))
                    return
                }
                
                // Check like status
                self?.db.collection("posts").document(postId).collection("likes").document(currentUser.uid).getDocument { likeSnapshot, _ in
                    let isLiked = likeSnapshot?.exists ?? false
                    let updatedPost = PostModel(
                        authorId: post.authorId,
                        authorName: post.authorName,
                        authorProfileImage: post.authorProfileImage,
                        content: post.content,
                        imageURL: post.imageURL,
                        likes: post.likes,
                        comments: post.comments,
                        isLikedByUser: isLiked
                    )
                    var finalPost = updatedPost
                    finalPost.id = postId
                    completion(.success(finalPost))
                }
            }
        }
        
        // MARK: - Debug Helper
        
        func testFirestoreRules(completion: @escaping (Result<String, Error>) -> Void) {
            guard let currentUser = Auth.auth().currentUser else {
                completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı giriş yapmamış"])))
                return
            }
            
            print("DEBUG: Firestore kuralları test ediliyor...")
            let testRef = db.collection("posts").document("test")
            
            testRef.setData(["test": "data"]) { error in
                if let error = error {
                    print("DEBUG: Firestore kural testi başarısız: \(error.localizedDescription)")
                    completion(.failure(error))
                } else {
                    print("DEBUG: Firestore kural testi başarılı")
                    testRef.delete { _ in
                        completion(.success("Kurallar çalışıyor"))
                    }
                }
            }
        }
        
        // MARK: - Data Migration Helper
        
        func forceCreateUserProfile(completion: @escaping (Result<UserProfileModel, Error>) -> Void) {
            guard let currentUser = Auth.auth().currentUser else {
                completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı giriş yapmamış"])))
                return
            }
            
            let email = currentUser.email ?? "kullanici@example.com"
            let defaultProfile = UserProfileModel(
                email: email,
                username: "kullanici_\(currentUser.uid.prefix(8))",
                fullName: "Kullanıcı",
                bio: "Bingo Social kullanıcısı",
                profileImageURL: "https://ui-avatars.com/api/?name=User&background=random&color=fff&size=200"
            )
            var newProfile = defaultProfile
            newProfile.id = currentUser.uid
            
            print("DEBUG: forceCreateUserProfile - Profil oluşturuluyor: \(newProfile.fullName)")
            
            createUserProfile(userProfile: newProfile) { result in
                switch result {
                case .success:
                    completion(.success(newProfile))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
        
        func updateAllUserContentWithProfileData(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
            ensureUserProfileExists(userId: userId) { [weak self] result in
                switch result {
                case .success(let profile):
                    guard let profile = profile else {
                        completion(.failure(NSError(domain: "Profile", code: -1, userInfo: [NSLocalizedDescriptionKey: "Profil bulunamadı"])))
                        return
                    }
                    
                    self?.updateUserPostsAndComments(userId: userId, userProfile: profile, completion: completion)
                    
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
