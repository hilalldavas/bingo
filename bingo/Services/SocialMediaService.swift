import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine
import UIKit

class SocialMediaService: ObservableObject {
    static let shared = SocialMediaService()
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - Posts
    
    func createPost(content: String, imageData: Data?, completion: @escaping (Result<PostModel, Error>) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı giriş yapmamış"])))
            return
        }
        
        let postRef = db.collection("posts").document()
        let postId = postRef.documentID
        
        // Eğer resim varsa, önce yükle sonra post'u kaydet
        if let imageData = imageData, let image = UIImage(data: imageData) {
            print("DEBUG: createPost - Resim yüklenecek, boyut: \(imageData.count) bytes")
            StorageService.shared.uploadPostImage(image, postId: postId, userId: currentUser.uid) { [weak self] result in
                switch result {
                case .success(let imageURL):
                    print("DEBUG: createPost - Resim yüklendi: \(imageURL)")
                    self?.savePost(postId: postId, content: content, imageURL: imageURL, completion: completion)
                case .failure(let error):
                    print("DEBUG: createPost - Resim yükleme hatası: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        } else {
            // Resim yoksa direkt post'u kaydet
            print("DEBUG: createPost - Sadece metin postu kaydediliyor")
            savePost(postId: postId, content: content, imageURL: nil, completion: completion)
        }
    }
    
    private func savePost(postId: String, content: String, imageURL: String?, completion: @escaping (Result<PostModel, Error>) -> Void) {
        guard let currentUser = Auth.auth().currentUser else { 
            completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı giriş yapmamış"])))
            return 
        }
        
        print("DEBUG: Post oluşturma - Kullanıcı ID: \(currentUser.uid)")
        print("DEBUG: Kullanıcı email: \(currentUser.email ?? "nil")")
        
        // Kullanıcının gerçek profil bilgilerini çek
        fetchUserProfile(userId: currentUser.uid) { [weak self] result in
            switch result {
            case .success(let profile):
                let authorName = profile?.fullName ?? "Kullanıcı"
                let authorProfileImage = profile?.profileImageURL
                
                print("DEBUG: Post için kullanılacak isim: \(authorName)")
                print("DEBUG: Post için kullanılacak profil fotoğrafı: \(authorProfileImage ?? "nil")")
                
                self?.createPostWithUserInfo(postId: postId, content: content, imageURL: imageURL, authorName: authorName, authorProfileImage: authorProfileImage, completion: completion)
                
            case .failure(let error):
                print("DEBUG: Profil bilgileri çekilemedi, varsayılan bilgiler kullanılacak: \(error.localizedDescription)")
                
                // Profil bilgileri çekilemezse varsayılan bilgiler kullan
                let authorName = currentUser.email?.components(separatedBy: "@").first?.capitalized ?? "Kullanıcı"
                let authorProfileImage = "https://ui-avatars.com/api/?name=\(authorName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "User")&background=random&color=fff&size=200"
                
                self?.createPostWithUserInfo(postId: postId, content: content, imageURL: imageURL, authorName: authorName, authorProfileImage: authorProfileImage, completion: completion)
            }
        }
    }
    
    private func createPostWithUserInfo(postId: String, content: String, imageURL: String?, authorName: String, authorProfileImage: String?, completion: @escaping (Result<PostModel, Error>) -> Void) {
        guard let currentUser = Auth.auth().currentUser else { 
            completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı giriş yapmamış"])))
            return 
        }
        
        let post = PostModel(
            authorId: currentUser.uid,
            authorName: authorName,
            authorProfileImage: authorProfileImage,
            content: content,
            imageURL: imageURL
        )
        
        print("DEBUG: createPostWithUserInfo - Post oluşturuluyor:")
        print("DEBUG: - authorName: \(authorName)")
        print("DEBUG: - authorProfileImage: \(authorProfileImage ?? "nil")")
        print("DEBUG: - timestamp: \(post.timestamp)")
        
        db.collection("posts").document(postId).setData(post.toDictionary()) { [weak self] error in
            if let error = error {
                completion(.failure(error))
            } else {
                // Post başarıyla oluşturulduysa kullanıcı istatistiğini güncelle
                self?.updateUserPostCount(userId: currentUser.uid, increment: 1) { _ in
                    print("DEBUG: Kullanıcı post sayısı güncellendi")
                }
                completion(.success(post))
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
                
                // Önce silinmiş kullanıcıların postlarını filtrele
                self?.filterPostsFromDeletedUsers(posts: posts, currentUserId: currentUser.uid, completion: completion)
            }
    }
    
    /// Sadece takip edilen kullanıcıların postlarını getirir (Instagram feed algoritması)
    func fetchFollowingPosts(completion: @escaping (Result<[PostModel], Error>) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı giriş yapmamış"])))
            return
        }
        
        // Önce takip edilen kullanıcıları çek
        db.collection("users").document(currentUser.uid).collection("following").getDocuments { [weak self] snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let followingDocs = snapshot?.documents else {
                // Kimseyi takip etmiyorsa tüm postları göster
                self?.fetchPosts(completion: completion)
                return
            }
            
            // Takip edilen kullanıcı ID'lerini al
            let followingIds = followingDocs.map { $0.documentID }
            
            // Kendi ID'sini de ekle (kendi postlarını da görmek için)
            var userIds = followingIds
            userIds.append(currentUser.uid)
            
            if userIds.isEmpty {
                completion(.success([]))
                return
            }
            
            // Takip edilen kullanıcıların postlarını çek (max 10 user ID per query)
            self?.fetchPostsByUserIds(userIds: Array(userIds.prefix(10)), currentUserId: currentUser.uid, completion: completion)
        }
    }
    
    private func fetchPostsByUserIds(userIds: [String], currentUserId: String, completion: @escaping (Result<[PostModel], Error>) -> Void) {
        db.collection("posts")
            .whereField("authorId", in: userIds)
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
                
                // Silinmiş ve dondurulmuş kullanıcıları filtrele
                self?.filterPostsFromDeletedUsers(posts: posts, currentUserId: currentUserId, completion: completion)
            }
    }
    
    /// Silinmiş ve dondurulmuş kullanıcıların postlarını filtreler
    private func filterPostsFromDeletedUsers(posts: [PostModel], currentUserId: String, completion: @escaping (Result<[PostModel], Error>) -> Void) {
        let dispatchGroup = DispatchGroup()
        var validPosts: [PostModel] = []
        
        for post in posts {
            dispatchGroup.enter()
            
            // Her post için author'un profilinin var olup olmadığını ve aktif olup olmadığını kontrol et
            fetchUserProfile(userId: post.authorId) { result in
                defer { dispatchGroup.leave() }
                
                switch result {
                case .success(let profile):
                    if let profile = profile {
                        // Profil var mı ve aktif mi kontrol et
                        if !profile.isDeactivated {
                            // Aktif kullanıcı, post'u ekle
                            validPosts.append(post)
                        } else {
                            print("DEBUG: Post atlandı - Kullanıcı hesabı dondurulmuş: \(post.authorId)")
                        }
                    } else {
                        print("DEBUG: Post atlandı - Kullanıcı profili bulunamadı: \(post.authorId)")
                    }
                case .failure:
                    // Hata durumunda da post'u dahil etme (güvenli taraf)
                    print("DEBUG: Post atlandı - Profil kontrol hatası: \(post.authorId)")
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            print("DEBUG: Toplam \(posts.count) post, \(validPosts.count) geçerli post")
            // Geçerli postlar için like kontrolü yap
            self.checkLikeStatusForPosts(posts: validPosts, userId: currentUserId, completion: completion)
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
                likeRef.setData(["userId": currentUser.uid, "timestamp": Date()]) { [weak self] error in
                    if let error = error {
                        print("DEBUG: Like hatası: \(error.localizedDescription)")
                        completion(.failure(error))
                    } else {
                        print("DEBUG: Like başarılı")
                        
                        // Post sahibine bildirim gönder
                        self?.db.collection("posts").document(postId).getDocument { snapshot, _ in
                            if let authorId = snapshot?.data()?["authorId"] as? String {
                                self?.createNotification(toUserId: authorId, type: .like, postId: postId) { _ in }
                            }
                        }
                        
                        self?.updatePostLikesAndFetch(postId: postId, increment: 1, currentUserId: currentUser.uid, completion: completion)
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
                    if let post = post {
                        print("DEBUG: Güncel post verileri çekildi - likes: \(post.likes), isLiked: \(post.isLikedByUser)")
                        completion(.success(post))
                    } else {
                        completion(.failure(NSError(domain: "Post", code: -1, userInfo: [NSLocalizedDescriptionKey: "Post bulunamadı"])))
                    }
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
        
        db.collection("posts").document(postId).collection("comments").addDocument(data: comment.toDictionary()) { [weak self] error in
            if let error = error {
                completion(.failure(error))
            } else {
                // Post sahibine bildirim gönder
                self?.db.collection("posts").document(postId).getDocument { snapshot, _ in
                    if let authorId = snapshot?.data()?["authorId"] as? String {
                        self?.createNotification(toUserId: authorId, type: .comment, postId: postId) { _ in }
                    }
                }
                
                // Update comment count
                self?.db.collection("posts").document(postId).updateData([
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
    
    /// Profil fotoğrafı yükler ve kullanıcı profilini günceller
    func uploadProfileImage(_ image: UIImage, userId: String, completion: @escaping (Result<String, Error>) -> Void) {
        print("DEBUG: uploadProfileImage - Başlatıldı")
        StorageService.shared.uploadProfileImage(image, userId: userId) { [weak self] result in
            switch result {
            case .success(let imageURL):
                print("DEBUG: uploadProfileImage - Başarılı: \(imageURL)")
                completion(.success(imageURL))
            case .failure(let error):
                print("DEBUG: uploadProfileImage - Hata: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    /// Post resmini siler (post silindiğinde)
    func deletePostImage(imageURL: String, completion: @escaping (Result<Void, Error>) -> Void) {
        StorageService.shared.deleteImage(at: imageURL, completion: completion)
    }
        
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
                    self?.updateUserPostsAndComments(userId: userId, userProfile: userProfile) { updateResult in
                        if case .failure(let error) = updateResult {
                            print("DEBUG: Error updating user posts/comments: \(error.localizedDescription)")
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
            db.collection("posts").whereField("authorId", isEqualTo: userId).getDocuments { [self] snapshot, error in
                defer { dispatchGroup.leave() }
                
                if let documents = snapshot?.documents {
                    for document in documents {
                        let postRef = self.db.collection("posts").document(document.documentID)
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
        
        // MARK: - Story System
        
        /// Yeni story oluşturur
        func createStory(imageData: Data?, completion: @escaping (Result<StoryModel, Error>) -> Void) {
            guard let currentUser = Auth.auth().currentUser else {
                completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı giriş yapmamış"])))
                return
            }
            
            let storyRef = db.collection("stories").document()
            let storyId = storyRef.documentID
            
            // Profil bilgilerini çek
            fetchUserProfile(userId: currentUser.uid) { [weak self] result in
                guard let self = self else { return }
                
                let authorName: String
                let authorProfileImage: String?
                
                switch result {
                case .success(let profile):
                    authorName = profile?.fullName ?? "Kullanıcı"
                    authorProfileImage = profile?.profileImageURL
                case .failure:
                    authorName = "Kullanıcı"
                    authorProfileImage = nil
                }
                
                if let imageData = imageData, let image = UIImage(data: imageData) {
                    // Önce fotoğrafı yükle
                    StorageService.shared.uploadStoryImage(image, storyId: storyId, userId: currentUser.uid) { uploadResult in
                        switch uploadResult {
                        case .success(let imageURL):
                            self.saveStory(storyId: storyId, authorName: authorName, authorProfileImage: authorProfileImage, imageURL: imageURL, completion: completion)
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                } else {
                    completion(.failure(NSError(domain: "Story", code: -1, userInfo: [NSLocalizedDescriptionKey: "Fotoğraf gerekli"])))
                }
            }
        }
        
        private func saveStory(storyId: String, authorName: String, authorProfileImage: String?, imageURL: String, completion: @escaping (Result<StoryModel, Error>) -> Void) {
            guard let currentUser = Auth.auth().currentUser else {
                completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı giriş yapmamış"])))
                return
            }
            
            let story = StoryModel(
                authorId: currentUser.uid,
                authorName: authorName,
                authorProfileImage: authorProfileImage,
                imageURL: imageURL
            )
            
            db.collection("stories").document(storyId).setData(story.toDictionary()) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(story))
                }
            }
        }
        
        /// Aktif storyleri getirir (24 saatten yeni)
        func fetchStories(completion: @escaping (Result<[String: [StoryModel]], Error>) -> Void) {
            guard let currentUser = Auth.auth().currentUser else {
                completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı giriş yapmamış"])))
                return
            }
            
            // 24 saat öncesi timestamp
            let twentyFourHoursAgo = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
            
            db.collection("stories")
                .whereField("timestamp", isGreaterThan: Timestamp(date: twentyFourHoursAgo))
                .order(by: "timestamp", descending: false)
                .getDocuments { snapshot, error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        completion(.success([:]))
                        return
                    }
                    
                    let stories = documents.compactMap { doc -> StoryModel? in
                        StoryModel.from(dict: doc.data(), id: doc.documentID)
                    }
                    
                    // Kullanıcılara göre grupla
                    var groupedStories: [String: [StoryModel]] = [:]
                    for story in stories {
                        if groupedStories[story.authorId] == nil {
                            groupedStories[story.authorId] = []
                        }
                        groupedStories[story.authorId]?.append(story)
                    }
                    
                    completion(.success(groupedStories))
                }
        }
        
        /// Story'yi görüntülendi olarak işaretle
        func markStoryAsViewed(storyId: String, userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
            db.collection("stories").document(storyId).updateData([
                "views": FieldValue.arrayUnion([userId])
            ]) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
        
        /// Eski storyleri sil (24 saatten eskiler)
        func deleteExpiredStories(completion: @escaping (Result<Void, Error>) -> Void) {
            let twentyFourHoursAgo = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
            
            db.collection("stories")
                .whereField("timestamp", isLessThan: Timestamp(date: twentyFourHoursAgo))
                .getDocuments { [weak self] snapshot, error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        completion(.success(()))
                        return
                    }
                    
                    let batch = self?.db.batch()
                    for document in documents {
                        batch?.deleteDocument(document.reference)
                    }
                    
                    batch?.commit { error in
                        if let error = error {
                            completion(.failure(error))
                        } else {
                            print("DEBUG: \(documents.count) eski story silindi")
                            completion(.success(()))
                        }
                    }
                }
        }
        
        // MARK: - Messaging (DM)
        
        /// Mesaj gönder
        func sendMessage(toUserId: String, text: String, completion: @escaping (Result<Void, Error>) -> Void) {
            guard let currentUserId = Auth.auth().currentUser?.uid else {
                completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı giriş yapmamış"])))
                return
            }
            
            let message = MessageModel(senderId: currentUserId, receiverId: toUserId, text: text)
            
            // Her iki kullanıcının messages koleksiyonuna ekle
            db.collection("messages").addDocument(data: message.toDictionary()) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
        
        /// Kullanıcılar arası mesajları getir
        func fetchMessages(withUserId: String, completion: @escaping (Result<[MessageModel], Error>) -> Void) {
            guard let currentUserId = Auth.auth().currentUser?.uid else {
                completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı giriş yapmamış"])))
                return
            }
            
            db.collection("messages")
                .whereFilter(Filter.orFilter([
                    Filter.andFilter([
                        Filter.whereField("senderId", isEqualTo: currentUserId),
                        Filter.whereField("receiverId", isEqualTo: withUserId)
                    ]),
                    Filter.andFilter([
                        Filter.whereField("senderId", isEqualTo: withUserId),
                        Filter.whereField("receiverId", isEqualTo: currentUserId)
                    ])
                ]))
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
                    
                    let messages = documents.compactMap { doc -> MessageModel? in
                        MessageModel.from(dict: doc.data(), id: doc.documentID)
                    }
                    
                    completion(.success(messages))
                }
        }
        
        // MARK: - Notifications
        
        /// Bildirim oluştur
        func createNotification(toUserId: String, type: NotificationType, postId: String? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
            guard let currentUser = Auth.auth().currentUser else {
                completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı giriş yapmamış"])))
                return
            }
            
            // Kendine bildirim gönderme
            if toUserId == currentUser.uid {
                completion(.success(()))
                return
            }
            
            // Kullanıcı bilgilerini çek
            fetchUserProfile(userId: currentUser.uid) { [weak self] result in
                guard let self = self else { return }
                
                let userName: String
                let userProfileImage: String?
                
                switch result {
                case .success(let profile):
                    userName = profile?.fullName ?? "Kullanıcı"
                    userProfileImage = profile?.profileImageURL
                case .failure:
                    userName = "Kullanıcı"
                    userProfileImage = nil
                }
                
                let notification = NotificationModel(
                    type: type,
                    fromUserId: currentUser.uid,
                    fromUserName: userName,
                    fromUserProfileImage: userProfileImage,
                    postId: postId
                )
                
                self.db.collection("users").document(toUserId).collection("notifications")
                    .addDocument(data: notification.toDictionary()) { error in
                        if let error = error {
                            completion(.failure(error))
                        } else {
                            print("DEBUG: Bildirim oluşturuldu: \(type.rawValue)")
                            completion(.success(()))
                        }
                    }
            }
        }
        
        /// Bildirimleri getir
        func fetchNotifications(userId: String, completion: @escaping (Result<[NotificationModel], Error>) -> Void) {
            db.collection("users").document(userId).collection("notifications")
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
                    
                    let notifications = documents.compactMap { doc -> NotificationModel? in
                        NotificationModel.from(dict: doc.data(), id: doc.documentID)
                    }
                    
                    completion(.success(notifications))
                }
        }
        
        /// Bildirimi okundu olarak işaretle
        func markNotificationAsRead(userId: String, notificationId: String, completion: @escaping (Result<Void, Error>) -> Void) {
            db.collection("users").document(userId).collection("notifications").document(notificationId)
                .updateData(["isRead": true]) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
        }
        
        // MARK: - Search & Discovery
        
        /// Kullanıcı ara (username veya fullName'de)
        func searchUsers(query: String, completion: @escaping (Result<[UserProfileModel], Error>) -> Void) {
            let lowercaseQuery = query.lowercased()
            
            db.collection("users")
                .limit(to: 20)
                .getDocuments { snapshot, error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        completion(.success([]))
                        return
                    }
                    
                    let users = documents.compactMap { doc -> UserProfileModel? in
                        UserProfileModel.from(dict: doc.data(), id: doc.documentID)
                    }.filter { user in
                        // Aktif olmayan kullanıcıları gösterme
                        if user.isDeactivated { return false }
                        
                        // Username veya fullName'de ara
                        let usernameMatch = user.username.lowercased().contains(lowercaseQuery)
                        let fullNameMatch = user.fullName.lowercased().contains(lowercaseQuery)
                        
                        return usernameMatch || fullNameMatch
                    }
                    
                    completion(.success(users))
                }
        }
        
        /// Trend (popüler) postları getirir
        func fetchTrendingPosts(completion: @escaping (Result<[PostModel], Error>) -> Void) {
            guard let currentUser = Auth.auth().currentUser else {
                completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı giriş yapmamış"])))
                return
            }
            
            // En çok beğenilen postları getir
            db.collection("posts")
                .order(by: "likes", descending: true)
                .order(by: "timestamp", descending: true)
                .limit(to: 30)
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
                    
                    // Silinmiş/dondurulmuş kullanıcıları filtrele
                    self?.filterPostsFromDeletedUsers(posts: posts, currentUserId: currentUser.uid, completion: completion)
                }
        }
        
        // MARK: - Follow System
        
        /// Kullanıcıyı takip et
        func followUser(userId: String, targetUserId: String, completion: @escaping (Result<Void, Error>) -> Void) {
            print("DEBUG: followUser - \(userId) takip ediyor: \(targetUserId)")
            
            let batch = db.batch()
            
            // 1. Takip eden kullanıcının "following" listesine ekle
            let followingRef = db.collection("users").document(userId).collection("following").document(targetUserId)
            batch.setData(["timestamp": Timestamp(date: Date())], forDocument: followingRef)
            
            // 2. Takip edilen kullanıcının "followers" listesine ekle
            let followerRef = db.collection("users").document(targetUserId).collection("followers").document(userId)
            batch.setData(["timestamp": Timestamp(date: Date())], forDocument: followerRef)
            
            // 3. Takip eden kullanıcının "following" sayısını artır
            let userRef = db.collection("users").document(userId)
            batch.updateData(["following": FieldValue.increment(Int64(1))], forDocument: userRef)
            
            // 4. Takip edilen kullanıcının "followers" sayısını artır
            let targetUserRef = db.collection("users").document(targetUserId)
            batch.updateData(["followers": FieldValue.increment(Int64(1))], forDocument: targetUserRef)
            
            batch.commit { [weak self] error in
                if let error = error {
                    print("DEBUG: followUser hatası: \(error.localizedDescription)")
                    completion(.failure(error))
                } else {
                    print("DEBUG: followUser başarılı")
                    
                    // Takip edilen kullanıcıya bildirim gönder
                    self?.createNotification(toUserId: targetUserId, type: .follow) { _ in }
                    
                    completion(.success(()))
                }
            }
        }
        
        /// Kullanıcıyı takipten çıkar
        func unfollowUser(userId: String, targetUserId: String, completion: @escaping (Result<Void, Error>) -> Void) {
            print("DEBUG: unfollowUser - \(userId) takipten çıkıyor: \(targetUserId)")
            
            let batch = db.batch()
            
            // 1. Takip eden kullanıcının "following" listesinden sil
            let followingRef = db.collection("users").document(userId).collection("following").document(targetUserId)
            batch.deleteDocument(followingRef)
            
            // 2. Takip edilen kullanıcının "followers" listesinden sil
            let followerRef = db.collection("users").document(targetUserId).collection("followers").document(userId)
            batch.deleteDocument(followerRef)
            
            // 3. Takip eden kullanıcının "following" sayısını azalt
            let userRef = db.collection("users").document(userId)
            batch.updateData(["following": FieldValue.increment(Int64(-1))], forDocument: userRef)
            
            // 4. Takip edilen kullanıcının "followers" sayısını azalt
            let targetUserRef = db.collection("users").document(targetUserId)
            batch.updateData(["followers": FieldValue.increment(Int64(-1))], forDocument: targetUserRef)
            
            batch.commit { error in
                if let error = error {
                    print("DEBUG: unfollowUser hatası: \(error.localizedDescription)")
                    completion(.failure(error))
                } else {
                    print("DEBUG: unfollowUser başarılı")
                    completion(.success(()))
                }
            }
        }
        
        /// Kullanıcıyı takip ediyor mu kontrol et
        func isFollowing(userId: String, targetUserId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
            db.collection("users").document(userId).collection("following").document(targetUserId).getDocument { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(snapshot?.exists ?? false))
                }
            }
        }
        
        // MARK: - Account Deactivation (30 days)
        
        /// Hesabı geçici olarak dondurur (30 gün)
        func deactivateAccount(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
            print("DEBUG: Hesap dondurma başlatıldı - UserID: \(userId)")
            
            db.collection("users").document(userId).updateData([
                "isDeactivated": true,
                "deactivatedAt": Timestamp(date: Date())
            ]) { error in
                if let error = error {
                    print("DEBUG: Hesap dondurma hatası: \(error.localizedDescription)")
                    completion(.failure(error))
                } else {
                    print("DEBUG: Hesap başarıyla donduruldu")
                    completion(.success(()))
                }
            }
        }
        
        /// Hesabı yeniden aktifleştirir
        func reactivateAccount(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
            print("DEBUG: Hesap yeniden aktifleştiriliyor - UserID: \(userId)")
            
            db.collection("users").document(userId).updateData([
                "isDeactivated": false,
                "deactivatedAt": FieldValue.delete()
            ]) { error in
                if let error = error {
                    print("DEBUG: Hesap aktifleştirme hatası: \(error.localizedDescription)")
                    completion(.failure(error))
                } else {
                    print("DEBUG: Hesap başarıyla aktifleştirildi")
                    completion(.success(()))
                }
            }
        }
        
        /// 30 günden fazla dondurulmuş hesapları kalıcı olarak siler
        func checkAndDeleteExpiredDeactivatedAccounts(userId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
            fetchUserProfile(userId: userId) { [weak self] result in
                switch result {
                case .success(let profile):
                    guard let profile = profile else {
                        completion(.success(false))
                        return
                    }
                    
                    if profile.isDeactivated, let deactivatedAt = profile.deactivatedAt {
                        let daysSinceDeactivation = Calendar.current.dateComponents([.day], from: deactivatedAt, to: Date()).day ?? 0
                        
                        print("DEBUG: Hesap \(daysSinceDeactivation) gündür dondurulmuş")
                        
                        if daysSinceDeactivation > 30 {
                            print("DEBUG: 30 gün geçmiş, hesap kalıcı olarak siliniyor...")
                            self?.deleteUserAndAllContent(userId: userId) { deleteResult in
                                switch deleteResult {
                                case .success:
                                    completion(.success(true)) // Hesap silindi
                                case .failure(let error):
                                    completion(.failure(error))
                                }
                            }
                        } else {
                            completion(.success(false)) // Henüz silinmedi
                        }
                    } else {
                        completion(.success(false)) // Aktif hesap
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
        
        // MARK: - User Deletion (Cascade)
        
        /// Kullanıcı silindiğinde tüm içeriğini siler (posts, comments, likes)
        func deleteUserAndAllContent(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
            let batch = db.batch()
            let dispatchGroup = DispatchGroup()
            
            print("DEBUG: Kullanıcı ve tüm içeriği siliniyor - UserID: \(userId)")
            
            // 1. Kullanıcının tüm postlarını sil
            dispatchGroup.enter()
            db.collection("posts").whereField("authorId", isEqualTo: userId).getDocuments { [weak self] snapshot, error in
                defer { dispatchGroup.leave() }
                
                if let documents = snapshot?.documents {
                    print("DEBUG: \(documents.count) post siliniyor...")
                    for document in documents {
                        batch.deleteDocument(document.reference)
                    }
                }
            }
            
            // 2. Kullanıcının tüm yorumlarını sil
            dispatchGroup.enter()
            db.collectionGroup("comments").whereField("authorId", isEqualTo: userId).getDocuments { snapshot, error in
                defer { dispatchGroup.leave() }
                
                if let documents = snapshot?.documents {
                    print("DEBUG: \(documents.count) yorum siliniyor...")
                    for document in documents {
                        batch.deleteDocument(document.reference)
                    }
                }
            }
            
            // 3. Kullanıcının tüm beğenilerini sil
            dispatchGroup.enter()
            db.collectionGroup("likes").whereField("userId", isEqualTo: userId).getDocuments { snapshot, error in
                defer { dispatchGroup.leave() }
                
                if let documents = snapshot?.documents {
                    print("DEBUG: \(documents.count) beğeni siliniyor...")
                    for document in documents {
                        batch.deleteDocument(document.reference)
                    }
                }
            }
            
            // 4. Son olarak kullanıcı profilini sil
            dispatchGroup.notify(queue: .main) { [weak self] in
                let userRef = self?.db.collection("users").document(userId)
                if let userRef = userRef {
                    batch.deleteDocument(userRef)
                }
                
                // Batch commit
                batch.commit { error in
                    if let error = error {
                        print("DEBUG: Kullanıcı silme hatası: \(error.localizedDescription)")
                        completion(.failure(error))
                    } else {
                        print("DEBUG: Kullanıcı ve tüm içeriği başarıyla silindi")
                        completion(.success(()))
                    }
                }
            }
        }
        
        // MARK: - Debug Helper
        
        func testFirestoreRules(completion: @escaping (Result<String, Error>) -> Void) {
            guard Auth.auth().currentUser != nil else {
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
