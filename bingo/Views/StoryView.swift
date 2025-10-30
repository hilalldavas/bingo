import SwiftUI
import FirebaseAuth

// MARK: - Story Ring (Feed üstü)
struct StoryRingView: View {
    let userId: String
    let profileImage: String?
    let username: String
    let hasUnviewedStory: Bool
    let isOwnStory: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    // Gradient ring (görülmemişse)
                    if hasUnviewedStory {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.purple, .pink, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2.5
                            )
                            .frame(width: 70, height: 70)
                    } else {
                        Circle()
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                            .frame(width: 70, height: 70)
                    }
                    
                    // Profile photo
                    AsyncImage(url: URL(string: profileImage ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color(.systemGray5))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.white)
                            )
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                    
                    // Kendi story'si için + butonu
                    if isOwnStory && !hasUnviewedStory {
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 24, y: 24)
                    }
                }
                
                Text(isOwnStory ? "Hikayen" : username)
                    .font(.caption2)
                    .lineLimit(1)
                    .frame(width: 70)
                    .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - Story Viewer (Tam ekran)
struct StoryViewerView: View {
    @Environment(\.dismiss) private var dismiss
    let stories: [StoryModel]
    let allStoriesGrouped: [String: [StoryModel]]
    @State private var currentStoryIndex = 0
    @State private var progress: Double = 0
    @State private var timer: Timer?
    
    var currentStory: StoryModel {
        stories[currentStoryIndex]
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            // Story Image
            if let imageURL = currentStory.imageURL {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                        .tint(.white)
                }
            }
            
            // Overlay gradient (top)
            LinearGradient(
                colors: [Color.black.opacity(0.6), Color.clear],
                startPoint: .top,
                endPoint: .center
            )
            .frame(height: 200)
            .frame(maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
            
            VStack {
                // Progress bars
                HStack(spacing: 4) {
                    ForEach(0..<stories.count, id: \.self) { index in
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                                .overlay(
                                    Rectangle()
                                        .fill(Color.white)
                                        .frame(width: index < currentStoryIndex ? geometry.size.width :
                                                (index == currentStoryIndex ? geometry.size.width * progress : 0)),
                                    alignment: .leading
                                )
                        }
                        .frame(height: 2)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 50)
                
                // Header
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: currentStory.authorProfileImage ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.white.opacity(0.3))
                    }
                    .frame(width: 35, height: 35)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentStory.authorName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("\(currentStory.hoursAgo)sa önce")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .font(.title3)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                Spacer()
            }
            
            // Tap areas (previous/next)
            HStack(spacing: 0) {
                // Previous
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        previousStory()
                    }
                
                // Next
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        nextStory()
                    }
            }
        }
        .onAppear {
            startTimer()
            markAsViewed()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        progress = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            if progress < 1.0 {
                progress += 0.01
            } else {
                nextStory()
            }
        }
    }
    
    private func nextStory() {
        if currentStoryIndex < stories.count - 1 {
            currentStoryIndex += 1
            startTimer()
            markAsViewed()
        } else {
            dismiss()
        }
    }
    
    private func previousStory() {
        if currentStoryIndex > 0 {
            currentStoryIndex -= 1
            startTimer()
        }
    }
    
    private func markAsViewed() {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              let storyId = currentStory.id else { return }
        
        SocialMediaService.shared.markStoryAsViewed(storyId: storyId, userId: currentUserId) { _ in }
    }
}

