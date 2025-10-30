import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct FeedView: View {
    @StateObject private var socialService = SocialMediaService.shared
    @State private var posts: [PostModel] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showCreatePost = false
    @State private var groupedStories: [String: [StoryModel]] = [:]
    @State private var showStoryViewer = false
    @State private var selectedStories: [StoryModel] = []
    @State private var showCreateStory = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [.purple.opacity(0.1), .blue.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        // Gradient Logo - Instagram tarzı
                        Text("bingo")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.pink, Color(red: 0.9, green: 0.2, blue: 0.6), .purple, Color(red: 0.5, green: 0.2, blue: 0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Spacer()
                        
                        Button(action: {
                            showCreatePost = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.purple)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    
                    // Stories - Instagram style
                    if !groupedStories.isEmpty || Auth.auth().currentUser != nil {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                // Kendi story'si (her zaman göster)
                                if let currentUserId = Auth.auth().currentUser?.uid {
                                    let userStories = groupedStories[currentUserId] ?? []
                                    let hasOwnStory = !userStories.isEmpty
                                    
                                    StoryRingView(
                                        userId: currentUserId,
                                        profileImage: getCurrentUserProfileImage(),
                                        username: "Hikayen",
                                        hasUnviewedStory: hasOwnStory,
                                        isOwnStory: true,
                                        action: {
                                            if hasOwnStory {
                                                selectedStories = userStories
                                                showStoryViewer = true
                                            } else {
                                                showCreateStory = true
                                            }
                                        }
                                    )
                                }
                                
                                // Diğer kullanıcıların storyleri
                                ForEach(sortedStoryUsers(), id: \.self) { userId in
                                    if let stories = groupedStories[userId],
                                       let firstStory = stories.first,
                                       userId != Auth.auth().currentUser?.uid {
                                        let hasUnviewed = hasUnviewedStories(stories: stories)
                                        
                                        StoryRingView(
                                            userId: userId,
                                            profileImage: firstStory.authorProfileImage,
                                            username: firstStory.authorName,
                                            hasUnviewedStory: hasUnviewed,
                                            isOwnStory: false,
                                            action: {
                                                selectedStories = stories
                                                showStoryViewer = true
                                            }
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                        }
                        .background(Color(.systemBackground))
                        
                        Divider()
                    }
                    
                    if isLoading {
                        Spacer()
                        ProgressView("Yükleniyor...")
                            .foregroundColor(.secondary)
                        Spacer()
                    } else if posts.isEmpty {
                        Spacer()
                        VStack(spacing: 20) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            
                            Text("Henüz hiç post yok")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Text("İlk postu sen paylaş!")
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                showCreatePost = true
                            }) {
                                Text("Post Paylaş")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 30)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(
                                            colors: [.purple, .blue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(25)
                            }
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 15) {
                                ForEach(posts) { post in
                                    PostCardView(post: post, onRefresh: {
                                        loadPosts()
                                    })
                                        .padding(.horizontal)
                                }
                            }
                            .padding(.top, 10)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showCreatePost) {
            CreatePostView(onPostCreated: { newPost in
                addNewPost(newPost)
            })
        }
        .sheet(isPresented: $showCreateStory) {
            CreateStoryView(onStoryCreated: {
                loadStories()
            })
        }
        .fullScreenCover(isPresented: $showStoryViewer) {
            if !selectedStories.isEmpty {
                StoryViewerView(
                    stories: selectedStories,
                    allStoriesGrouped: groupedStories
                )
            }
        }
        .onAppear {
            loadPosts()
            loadStories()
            // Ensure current user has a profile
            if let currentUser = Auth.auth().currentUser {
                SocialMediaService.shared.ensureUserProfileExists(userId: currentUser.uid) { result in
                    switch result {
                    case .success(let profile):
                        if let profile = profile {
                            print("DEBUG: Kullanıcı profili mevcut: \(profile.fullName)")
                        }
                    case .failure(let error):
                        print("DEBUG: Profil kontrol hatası: \(error.localizedDescription)")
                    }
                }
            }
        }
        .refreshable {
            loadPosts()
        }
    }
    
    private func loadPosts() {
        isLoading = true
        errorMessage = ""
        
        // Instagram gibi: Sadece takip edilenlerden + kendi postlarından
        socialService.fetchFollowingPosts { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let fetchedPosts):
                    // Update existing posts instead of replacing the entire array
                    updatePostsWithNewData(fetchedPosts)
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func updatePostsWithNewData(_ newPosts: [PostModel]) {
        // Basit yaklaşım: Yeni postları direkt kullan, duplicate'ları önlemek için
        posts = newPosts
    }
    
    func addNewPost(_ post: PostModel) {
        // Yeni post'u en üste ekle
        posts.insert(post, at: 0)
    }
    
    private func loadStories() {
        socialService.fetchStories { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let stories):
                    groupedStories = stories
                case .failure(let error):
                    print("DEBUG: Story yükleme hatası: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func sortedStoryUsers() -> [String] {
        groupedStories.keys.sorted { userId1, userId2 in
            // Kendi story'si en önde
            if userId1 == Auth.auth().currentUser?.uid { return true }
            if userId2 == Auth.auth().currentUser?.uid { return false }
            
            // Görülmemişler önce
            let unviewed1 = hasUnviewedStories(stories: groupedStories[userId1] ?? [])
            let unviewed2 = hasUnviewedStories(stories: groupedStories[userId2] ?? [])
            if unviewed1 && !unviewed2 { return true }
            if !unviewed1 && unviewed2 { return false }
            
            // Sonra en yeniler
            let timestamp1 = groupedStories[userId1]?.first?.timestamp ?? Date.distantPast
            let timestamp2 = groupedStories[userId2]?.first?.timestamp ?? Date.distantPast
            return timestamp1 > timestamp2
        }
    }
    
    private func hasUnviewedStories(stories: [StoryModel]) -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        
        for story in stories {
            if !story.views.contains(currentUserId) {
                return true
            }
        }
        return false
    }
    
    private func getCurrentUserProfileImage() -> String? {
        // Bu fonksiyon için UserDefaults veya cache kullanılabilir
        // Şimdilik nil dönüyoruz, profil fotoğrafı placeholder gösterilecek
        return nil
    }
}

struct PostCardView: View {
    let post: PostModel
    let onRefresh: (() -> Void)?
    @State private var isLiked = false
    @State private var likeCount = 0
    @State private var commentCount = 0
    @State private var showComments = false
    @State private var showPostMenu = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var showEditSheet = false
    @State private var editedContent = ""
    @State private var isFollowing = false
    @State private var isFollowLoading = false
    @State private var showUserProfile = false
    
    init(post: PostModel, onRefresh: (() -> Void)? = nil) {
        self.post = post
        self.onRefresh = onRefresh
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author info
            HStack(spacing: 12) {
                // Profile photo - tıklanabilir
                Button(action: {
                    if post.authorId != Auth.auth().currentUser?.uid {
                        showUserProfile = true
                    }
                }) {
                AsyncImage(url: URL(string: post.authorProfileImage ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                                .font(.title3)
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(formatTimestamp(post.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Takip Et butonu - sadece başka kullanıcılar için
                if post.authorId != Auth.auth().currentUser?.uid {
                    if isFollowLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button(action: {
                            toggleFollow()
                        }) {
                            Text(isFollowing ? "Takiptesin" : "Takip Et")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(isFollowing ? .primary : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isFollowing ? Color(.systemGray5) : Color.purple)
                                .cornerRadius(8)
                        }
                    }
                }
                
                Menu {
                    // Kendi postumuz mu kontrol et
                    if post.authorId == Auth.auth().currentUser?.uid {
                        Button(action: {
                            editedContent = post.content
                            showEditSheet = true
                        }) {
                            Label("Düzenle", systemImage: "pencil")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: {
                            showDeleteConfirmation = true
                        }) {
                            Label("Sil", systemImage: "trash")
                        }
                    } else {
                        Button(action: {
                            // Şikayet et özelliği
                        }) {
                            Label("Şikayet Et", systemImage: "exclamationmark.triangle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                        .font(.title3)
                        .padding(8)
                }
            }
            .confirmationDialog("Bu postu silmek istediğinize emin misiniz?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Sil", role: .destructive) {
                    deletePost()
                }
                Button("İptal", role: .cancel) {}
            }
            
            // Post content - Sadece boş değilse göster
            if !post.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(post.content)
                .font(.body)
                .lineLimit(nil)
            }
            
            // Post image
            if let imageURL = post.imageURL {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay(
                            ProgressView()
                                .tint(.white)
                        )
                }
                .cornerRadius(12)
            }
            
            // Actions
            HStack(spacing: 20) {
                Button(action: {
                    toggleLike()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : .secondary)
                            .font(.title3)
                        
                        Text("\(likeCount)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(action: {
                    showComments = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "message")
                            .foregroundColor(.secondary)
                            .font(.title3)
                        
                        Text("\(commentCount)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
                
                Spacer()
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        .onAppear {
            isLiked = post.isLikedByUser
            likeCount = post.likes
            commentCount = post.comments
            
            // Takip durumunu kontrol et
            if post.authorId != Auth.auth().currentUser?.uid {
                checkFollowStatus()
            }
        }
        .sheet(isPresented: $showUserProfile) {
            if let currentUserId = Auth.auth().currentUser?.uid {
                UserProfileView(userId: post.authorId, currentUserId: currentUserId)
            }
        }
        .onChange(of: post.isLikedByUser) { _, newValue in
            isLiked = newValue
        }
        .onChange(of: post.likes) { _, newValue in
            likeCount = newValue
        }
        .onChange(of: post.comments) { _, newValue in
            commentCount = newValue
        }
        .sheet(isPresented: $showComments) {
            CommentsView(postId: post.id ?? "") {
                // Hemen yorum sayısını artır
                commentCount += 1
                // Sonra parent view'ı da güncelle
                onRefresh?()
            }
        }
        .sheet(isPresented: $showEditSheet) {
            PostEditView(
                postId: post.id ?? "",
                originalContent: post.content,
                editedContent: $editedContent,
                onSave: { newContent in
                    updatePost(newContent: newContent)
                }
            )
        }
        .overlay {
            if isDeleting {
                ZStack {
                    Color.black.opacity(0.3)
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.purple)
                        
                        Text("Siliniyor...")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(radius: 10)
                    )
                }
            }
        }
    }
    
    private func updatePost(newContent: String) {
        guard let postId = post.id else { return }
        
        // Firestore'da post içeriğini güncelle
        let db = Firestore.firestore()
        db.collection("posts").document(postId).updateData([
            "content": newContent
        ]) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("DEBUG: Post güncelleme hatası: \(error.localizedDescription)")
                } else {
                    print("DEBUG: Post başarıyla güncellendi")
                    showEditSheet = false
                    onRefresh?()
                }
            }
        }
    }
    
    private func deletePost() {
        guard let postId = post.id else { return }
        
        isDeleting = true
        
        SocialMediaService.shared.deletePost(postId: postId) { result in
            DispatchQueue.main.async {
                isDeleting = false
                
                switch result {
                case .success:
                    print("DEBUG: Post başarıyla silindi")
                    onRefresh?()
                case .failure(let error):
                    print("DEBUG: Post silme hatası: \(error.localizedDescription)")
                    // Hata mesajı gösterilebilir
                }
            }
        }
    }
    
    private func checkFollowStatus() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        SocialMediaService.shared.isFollowing(userId: currentUserId, targetUserId: post.authorId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let following):
                    isFollowing = following
                case .failure(let error):
                    print("DEBUG: Takip durumu kontrol hatası: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func toggleFollow() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        isFollowLoading = true
        
        if isFollowing {
            // Takipten çık
            SocialMediaService.shared.unfollowUser(userId: currentUserId, targetUserId: post.authorId) { result in
                DispatchQueue.main.async {
                    isFollowLoading = false
                    switch result {
                    case .success:
                        isFollowing = false
                    case .failure(let error):
                        print("DEBUG: Takipten çıkma hatası: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            // Takip et
            SocialMediaService.shared.followUser(userId: currentUserId, targetUserId: post.authorId) { result in
                DispatchQueue.main.async {
                    isFollowLoading = false
                    switch result {
                    case .success:
                        isFollowing = true
                    case .failure(let error):
                        print("DEBUG: Takip etme hatası: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func toggleLike() {
        guard let postId = post.id else { return }
        
        print("DEBUG: toggleLike çağrıldı - PostID: \(postId), Mevcut durum: isLiked=\(isLiked), likeCount=\(likeCount)")
        
        let originalLiked = isLiked
        let originalCount = likeCount
        
        // Optimistic update
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1
        
        print("DEBUG: Optimistic update - isLiked: \(isLiked), likeCount: \(likeCount)")
        
        SocialMediaService.shared.likePost(postId: postId) { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    print("DEBUG: Like işlemi başarısız - \(error.localizedDescription)")
                    // Revert on error
                    isLiked = originalLiked
                    likeCount = originalCount
                case .success(let updatedPost):
                    print("DEBUG: Like işlemi başarılı - likes: \(updatedPost.likes), isLiked: \(updatedPost.isLikedByUser)")
                    // Update with real data from server
                    isLiked = updatedPost.isLikedByUser
                    likeCount = updatedPost.likes
                    // Also refresh parent view to update other instances
                    onRefresh?()
                }
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Post Edit View
struct PostEditView: View {
    @Environment(\.dismiss) private var dismiss
    let postId: String
    let originalContent: String
    @Binding var editedContent: String
    let onSave: (String) -> Void
    @State private var characterCount = 0
    private let maxCharacters = 500
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("Post'u Düzenle")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Text Editor
                VStack(alignment: .leading, spacing: 12) {
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.purple.opacity(0.3), lineWidth: 1.5)
                            )
                        
                        TextEditor(text: $editedContent)
                            .font(.body)
                            .padding(16)
                            .frame(minHeight: 200)
                            .scrollContentBackground(.hidden)
                            .onChange(of: editedContent) { _, newValue in
                                characterCount = newValue.count
                                if newValue.count > maxCharacters {
                                    editedContent = String(newValue.prefix(maxCharacters))
                                }
                            }
                        
                        if editedContent.isEmpty {
                            Text("Düşüncelerini paylaş... 💭")
                                .foregroundColor(.secondary.opacity(0.6))
                                .font(.body)
                                .padding(.leading, 20)
                                .padding(.top, 24)
                                .allowsHitTesting(false)
                        }
                    }
                    
                    // Character counter
                    HStack {
                        Spacer()
                        Text("\(characterCount)/\(maxCharacters)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(characterCount > maxCharacters * 9 / 10 ? .red : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(.systemGray5))
                            )
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                    .foregroundColor(.purple)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kaydet") {
                        onSave(editedContent)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: editedContent.isEmpty ? [.gray, .gray] : [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
                    .disabled(editedContent.isEmpty)
                }
            }
            .onAppear {
                characterCount = editedContent.count
            }
        }
    }
}

// MARK: - User Profile View (Başka Kullanıcının Profili)
struct UserProfileView: View {
    @Environment(\.dismiss) private var dismiss
    let userId: String
    let currentUserId: String
    
    @State private var userProfile: UserProfileModel?
    @State private var userPosts: [PostModel] = []
    @State private var isLoading = true
    @State private var isFollowing = false
    @State private var isFollowLoading = false
    @State private var selectedFilter: ProfilePostFilter = .all
    
    private var filteredPosts: [PostModel] {
        switch selectedFilter {
        case .all:
            return userPosts
        case .photos:
            return userPosts.filter { $0.imageURL != nil }
        case .text:
            return userPosts.filter { $0.imageURL == nil }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                if isLoading {
                    ProgressView("Profil yükleniyor...")
                        .padding()
                } else if let profile = userProfile {
                    VStack(spacing: 0) {
                        // Header
                        VStack(spacing: 16) {
                            // Username + Close
                            HStack {
                                Text(profile.fullName)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                Button("Kapat") {
                                    dismiss()
                                }
                                .foregroundColor(.purple)
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                            
                            // Profil fotoğrafı + Stats
                            HStack(spacing: 20) {
                                // Profile photo
                                AsyncImage(url: URL(string: profile.profileImageURL ?? "")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle()
                                        .fill(LinearGradient(
                                            colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .foregroundColor(.white)
                                                .font(.system(size: 35))
                                        )
                                }
                                .frame(width: 85, height: 85)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [.purple.opacity(0.5), .blue.opacity(0.4)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2
                                        )
                                )
                                
                                // Stats
                                HStack(spacing: 0) {
                                    StatView(count: userPosts.count, label: "gönderi")
                                    StatView(count: profile.followers, label: "takipçi")
                                    StatView(count: profile.following, label: "takip")
                                }
                            }
                            .padding(.horizontal)
                            
                            // Username + Bio
                            VStack(alignment: .leading, spacing: 4) {
                                Text("@\(profile.username)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                if let bio = profile.bio, !bio.isEmpty {
                                    Text(bio)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            
                            // Takip Et + Mesaj Butonları
                            HStack(spacing: 12) {
                                Button(action: {
                                    toggleFollow()
                                }) {
                                    if isFollowLoading {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text(isFollowing ? "Takipten Çık" : "Takip Et")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    LinearGradient(
                                        colors: isFollowing ? [Color.secondary, Color.secondary] : [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(8)
                                .disabled(isFollowLoading)
                                
                                Button(action: {
                                    // Mesaj gönder (placeholder)
                                }) {
                                    Image(systemName: "message.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.purple)
                                }
                                .frame(width: 44, height: 36)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 16)
                        
                        Divider()
                        
                        // Tabs
                        HStack(spacing: 0) {
                            ForEach([ProfilePostFilter.all, .photos, .text], id: \.self) { filter in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedFilter = filter
                                    }
                                }) {
                                    VStack(spacing: 8) {
                                        Image(systemName: filterIcon(for: filter))
                                            .font(.title3)
                                            .foregroundColor(selectedFilter == filter ? .primary : .secondary)
                                        
                                        Rectangle()
                                            .fill(selectedFilter == filter ? Color.primary : Color.clear)
                                            .frame(height: 1)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.top, 8)
                        
                        Divider()
                        
                        // Grid
                        if filteredPosts.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 50))
                                    .foregroundColor(.secondary)
                                
                                Text("Henüz paylaşım yok")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 60)
                        } else {
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 2),
                                GridItem(.flexible(), spacing: 2),
                                GridItem(.flexible(), spacing: 2)
                            ], spacing: 2) {
                                ForEach(filteredPosts) { post in
                                    PostGridItem(post: post)
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                loadUserData()
            }
        }
    }
    
    private func filterIcon(for filter: ProfilePostFilter) -> String {
        switch filter {
        case .all: return "square.grid.3x3.fill"
        case .photos: return "photo.fill"
        case .text: return "text.quote"
        }
    }
    
    private func loadUserData() {
        isLoading = true
        
        // Profil bilgilerini yükle
        SocialMediaService.shared.fetchUserProfile(userId: userId) { [self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let profile):
                    userProfile = profile
                case .failure(let error):
                    print("DEBUG: Profil yükleme hatası: \(error.localizedDescription)")
                }
            }
        }
        
        // Kullanıcının postlarını yükle
        SocialMediaService.shared.fetchPosts { [self] result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let allPosts):
                    userPosts = allPosts.filter { $0.authorId == userId }
                case .failure(let error):
                    print("DEBUG: Post yükleme hatası: \(error.localizedDescription)")
                }
            }
        }
        
        // Takip durumunu kontrol et
        SocialMediaService.shared.isFollowing(userId: currentUserId, targetUserId: userId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let following):
                    isFollowing = following
                case .failure(let error):
                    print("DEBUG: Takip durumu hatası: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func toggleFollow() {
        isFollowLoading = true
        
        if isFollowing {
            SocialMediaService.shared.unfollowUser(userId: currentUserId, targetUserId: userId) { result in
                DispatchQueue.main.async {
                    isFollowLoading = false
                    switch result {
                    case .success:
                        isFollowing = false
                        // Profili yeniden yükle (follower sayısı güncellensin)
                        loadUserData()
                    case .failure(let error):
                        print("DEBUG: Takipten çıkma hatası: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            SocialMediaService.shared.followUser(userId: currentUserId, targetUserId: userId) { result in
                DispatchQueue.main.async {
                    isFollowLoading = false
                    switch result {
                    case .success:
                        isFollowing = true
                        // Profili yeniden yükle (follower sayısı güncellensin)
                        loadUserData()
                    case .failure(let error):
                        print("DEBUG: Takip etme hatası: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
