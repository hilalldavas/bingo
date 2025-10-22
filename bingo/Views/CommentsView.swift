import SwiftUI
import FirebaseAuth

struct CommentsView: View {
    let postId: String
    @StateObject private var socialService = SocialMediaService.shared
    @State private var comments: [CommentModel] = []
    @State private var newComment = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var commentCount = 0
    @Environment(\.dismiss) private var dismiss
    
    let onCommentAdded: (() -> Void)?
    
    init(postId: String, onCommentAdded: (() -> Void)? = nil) {
        self.postId = postId
        self.onCommentAdded = onCommentAdded
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Kapat") {
                        dismiss()
                    }
                    .foregroundColor(.purple)
                    
                    Spacer()
                    
                    Text("Yorumlar")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    // Invisible button for balance
                    Button("Kapat") {
                        dismiss()
                    }
                    .opacity(0)
                }
                .padding()
                
                Divider()
                
                // Comments list with proper spacing
                if isLoading {
                    Spacer()
                    ProgressView("Yükleniyor...")
                        .foregroundColor(.secondary)
                    Spacer()
                } else if comments.isEmpty {
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "message")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        Text("Henüz hiç yorum yok")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text("İlk yorumu sen yap!")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(comments) { comment in
                                    CommentRowView(comment: comment)
                                        .padding(.horizontal)
                                        .id(comment.id)
                                }
                                
                                // Bottom padding to prevent overlap with input
                                Color.clear
                                    .frame(height: 20)
                            }
                            .padding(.top, 10)
                        }
                        .onChange(of: comments.count) { _ in
                            // Auto-scroll to bottom when new comment is added
                            if let lastComment = comments.last {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(lastComment.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                
                Divider()
                
                // Fixed comment input at bottom
                HStack(spacing: 12) {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 35, height: 35)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                                .font(.caption)
                        )
                    
                    TextField("Yorum yap...", text: $newComment)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            if !newComment.isEmpty {
                                addComment()
                            }
                        }
                    
                    Button(action: {
                        addComment()
                    }) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(newComment.isEmpty ? .secondary : .purple)
                            .font(.title3)
                    }
                    .disabled(newComment.isEmpty)
                }
                .padding()
                .background(
                    Color(.systemBackground)
                        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: -1)
                )
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadComments()
        }
        .alert("Hata", isPresented: .constant(!errorMessage.isEmpty)) {
            Button("Tamam") {
                errorMessage = ""
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func loadComments() {
        isLoading = true
        
        socialService.fetchComments(postId: postId) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let fetchedComments):
                    comments = fetchedComments
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func addComment() {
        guard !newComment.isEmpty else { return }
        
        let commentText = newComment
        newComment = ""
        
        // Optimistic update - hemen yorumu ekle
        let tempComment = CommentModel(
            postId: postId,
            authorId: Auth.auth().currentUser?.uid ?? "",
            authorName: "Sen", // Geçici olarak "Sen" göster
            authorProfileImage: nil,
            content: commentText
        )
        comments.append(tempComment)
        onCommentAdded?() // Hemen parent view'ı güncelle
        
        socialService.addComment(postId: postId, content: commentText) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    loadComments() // Reload comments with real data
                    onCommentAdded?() // Notify parent view to refresh
                case .failure(let error):
                    // Remove the temporary comment on error
                    comments.removeAll { $0.content == commentText }
                    errorMessage = error.localizedDescription
                    newComment = commentText // Restore comment text on error
                    onCommentAdded?() // Notify parent view to refresh
                }
            }
        }
    }
}

struct CommentRowView: View {
    let comment: CommentModel
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AsyncImage(url: URL(string: comment.authorProfileImage ?? "")) { image in
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
                            .font(.caption)
                    )
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(comment.authorName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(formatTimestamp(comment.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(comment.content)
                    .font(.body)
                    .lineLimit(nil)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    CommentsView(postId: "sample-post-id")
}

