import SwiftUI
import FirebaseAuth

struct FeedView: View {
    @StateObject private var socialService = SocialMediaService.shared
    @State private var posts: [PostModel] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showCreatePost = false
    
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
                        Text("Bingo Social 🎯")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
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
            CreatePostView(onPostCreated: {
                loadPosts()
            })
        }
        .onAppear {
            loadPosts()
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
        
        socialService.fetchPosts { result in
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
        // If posts array is empty, just set the new posts
        if posts.isEmpty {
            posts = newPosts
            return
        }
        
        // Update existing posts with new data
        for (index, existingPost) in posts.enumerated() {
            if let newPost = newPosts.first(where: { $0.id == existingPost.id }) {
                posts[index] = newPost
            }
        }
        
        // Add any new posts that don't exist in the current array
        for newPost in newPosts {
            if !posts.contains(where: { $0.id == newPost.id }) {
                posts.append(newPost)
            }
        }
        
        // Remove posts that no longer exist
        posts.removeAll { existingPost in
            !newPosts.contains(where: { $0.id == existingPost.id })
        }
        
        // Sort posts by timestamp
        posts.sort { $0.timestamp > $1.timestamp }
    }
}

struct PostCardView: View {
    let post: PostModel
    let onRefresh: (() -> Void)?
    @State private var isLiked = false
    @State private var likeCount = 0
    @State private var commentCount = 0
    @State private var showComments = false
    
    init(post: PostModel, onRefresh: (() -> Void)? = nil) {
        self.post = post
        self.onRefresh = onRefresh
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author info
            HStack(spacing: 12) {
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
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(formatTimestamp(post.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }
            
            // Post content
            Text(post.content)
                .font(.body)
                .lineLimit(nil)
            
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
        }
        .onChange(of: post.isLikedByUser) { newValue in
            isLiked = newValue
        }
        .onChange(of: post.likes) { newValue in
            likeCount = newValue
        }
        .onChange(of: post.comments) { newValue in
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

#Preview {
    FeedView()
}

