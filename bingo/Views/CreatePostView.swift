import SwiftUI

struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var socialService = SocialMediaService.shared
    @State private var postContent = ""
    @State private var selectedImage: UIImage?
    @State private var showingImageSourcePicker = false
    @State private var showingCamera = false
    @State private var showingGallery = false
    @State private var isPosting = false
    @State private var errorMessage = ""
    @State private var characterCount = 0
    @State private var showCharacterLimit = false
    
    let onPostCreated: (PostModel) -> Void
    let maxCharacters = 500
    
    private var canPost: Bool {
        // En az biri dolu olmalı
        return !postContent.isEmpty || selectedImage != nil
    }
    
    private var postTypeDescription: String {
        if selectedImage != nil && !postContent.isEmpty {
            return "Metin + Fotoğraf 🎨"
        } else if selectedImage != nil {
            return "Fotoğraf 📸"
        } else if !postContent.isEmpty {
            return "Metin 📝"
        }
        return ""
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                ZStack {
                    // Background gradient
                    LinearGradient(
                        colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.1)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                    .font(.body.weight(.semibold))
                                Text("İptal")
                                    .font(.body)
                            }
                            .foregroundColor(.purple)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 2) {
                            Text("Yeni Post Oluştur")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            if !postTypeDescription.isEmpty {
                                Text(postTypeDescription)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            createPost()
                        }) {
                            HStack(spacing: 4) {
                                Text("Paylaş")
                                    .font(.body.weight(.semibold))
                                Image(systemName: "paperplane.fill")
                                    .font(.body)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: canPost ? [.purple, .blue] : [.gray, .gray],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(20)
                        }
                        .disabled(!canPost || isPosting)
                    }
                    .padding()
                }
                .frame(height: 60)
                
                Divider()
                
                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Author info
                        HStack(spacing: 12) {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.white)
                                        .font(.title3)
                                )
                            
                            VStack(alignment: .leading) {
                                Text("Sen")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text("Şimdi")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        // Text input - Geliştirilmiş tasarım
                        VStack(alignment: .leading, spacing: 8) {
                            Text(selectedImage != nil ? "Açıklama (opsiyonel)" : "Ne düşünüyorsun?")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            ZStack(alignment: .topLeading) {
                                // Premium arka plan
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(.systemBackground), Color.purple.opacity(0.03)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [Color.purple.opacity(0.4), Color.blue.opacity(0.3)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 2
                                            )
                                    )
                                    .shadow(color: .purple.opacity(0.1), radius: 8, x: 0, y: 4)
                                
                                TextEditor(text: $postContent)
                                    .font(.body)
                                    .padding(16)
                                    .frame(minHeight: selectedImage != nil ? 120 : 200)
                                    .scrollContentBackground(.hidden)
                                    .onChange(of: postContent) { newValue in
                                        characterCount = newValue.count
                                        if newValue.count > maxCharacters {
                                            postContent = String(newValue.prefix(maxCharacters))
                                        }
                                        showCharacterLimit = newValue.count > maxCharacters * 3 / 4
                                    }
                                
                                if postContent.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(selectedImage != nil ? "Fotoğrafınız için açıklama..." : "Düşüncelerini paylaş...")
                                            .foregroundColor(.secondary.opacity(0.7))
                                            .font(.body)
                                        
                                        Text("💭")
                                            .font(.title2)
                                    }
                                    .padding(.leading, 20)
                                    .padding(.top, 20)
                                    .allowsHitTesting(false)
                                }
                            }
                            
                            // Premium character counter
                            HStack(spacing: 8) {
                                if selectedImage != nil {
                                    HStack(spacing: 4) {
                                        Image(systemName: "info.circle.fill")
                                            .font(.caption2)
                                            .foregroundColor(.purple.opacity(0.6))
                                        Text("Açıklama opsiyonel")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(characterCount > maxCharacters * 9 / 10 ? Color.red.opacity(0.2) : Color.purple.opacity(0.1))
                                        .frame(width: 6, height: 6)
                                    
                                    Text("\(characterCount)/\(maxCharacters)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(characterCount > maxCharacters * 9 / 10 ? .red : .secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color(.systemGray6))
                                )
                            }
                        }
                        
                        // Photo Section - Premium Tasarım
                        VStack(alignment: .leading, spacing: 12) {
                            if let selectedImage = selectedImage {
                                // Photo Preview - Büyük ve etkileyici
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: selectedImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 350)
                                        .clipped()
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [Color.purple.opacity(0.5), Color.blue.opacity(0.4)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 3
                                                )
                                        )
                                        .shadow(color: .purple.opacity(0.2), radius: 15, x: 0, y: 8)
                                    
                                    // Silme butonu - daha şık
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3)) {
                                            self.selectedImage = nil
                                        }
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [Color.red.opacity(0.95), Color.red.opacity(0.85)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 40, height: 40)
                                                .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
                                            
                                            Image(systemName: "xmark")
                                                .font(.body.weight(.bold))
                                                .foregroundColor(.white)
                                        }
                                        .padding(16)
                                    }
                                }
                            } else {
                                // Fotoğraf ekleme butonu - çok daha şık
                                Button(action: {
                                    showingImageSourcePicker = true
                                }) {
                                    VStack(spacing: 16) {
                                        ZStack {
                                            // Animated gradient circle
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [.purple.opacity(0.2), .blue.opacity(0.15)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 70, height: 70)
                                            
                                            Circle()
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [.purple.opacity(0.4), .blue.opacity(0.3)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 2
                                                )
                                                .frame(width: 70, height: 70)
                                            
                                            Image(systemName: "photo.badge.plus")
                                                .font(.system(size: 28))
                                                .foregroundColor(.purple)
                                        }
                                        
                                        VStack(spacing: 6) {
                                            Text("Fotoğraf Ekle")
                                                .font(.headline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.primary)
                                            
                                            Text("Kameradan çek veya galeriden seç")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color(.systemBackground), Color.purple.opacity(0.03)],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(
                                                style: StrokeStyle(lineWidth: 2, dash: [10, 5])
                                            )
                                            .foregroundColor(.purple.opacity(0.3))
                                    )
                                    .shadow(color: .purple.opacity(0.08), radius: 10, x: 0, y: 5)
                                }
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
            }
            
        }
        .navigationBarHidden(true)
        .confirmationDialog("Fotoğraf Ekle", isPresented: $showingImageSourcePicker, titleVisibility: .visible) {
            Button(action: {
                showingCamera = true
            }) {
                Label("Kameradan Çek", systemImage: "camera.fill")
            }
            
            Button(action: {
                showingGallery = true
            }) {
                Label("Galeriden Seç", systemImage: "photo.on.rectangle")
            }
            
            if selectedImage != nil {
                Button(role: .destructive, action: {
                    selectedImage = nil
                }) {
                    Label("Fotoğrafı Kaldır", systemImage: "trash")
                }
            }
            
            Button("İptal", role: .cancel) {}
        } message: {
            Text("Post'unuza fotoğraf eklemek için bir seçenek seçin")
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(image: $selectedImage, sourceType: .camera)
        }
        .sheet(isPresented: $showingGallery) {
            ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
        }
        .overlay {
            if isPosting {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 24) {
                        // Animated progress
                        ZStack {
                            Circle()
                                .stroke(Color.purple.opacity(0.3), lineWidth: 4)
                                .frame(width: 60, height: 60)
                            
                            ProgressView()
                                .scaleEffect(1.8)
                                .tint(.purple)
                        }
                        
                        VStack(spacing: 8) {
                            Text("Post Paylaşılıyor...")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            if selectedImage != nil {
                                Text("Fotoğraf yükleniyor")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(40)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                    )
                }
            }
        }
        .alert("Hata", isPresented: .constant(!errorMessage.isEmpty)) {
            Button("Tamam") {
                errorMessage = ""
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func createPost() {
        // En az biri dolu olmalı
        guard !postContent.isEmpty || selectedImage != nil else { return }
        
        isPosting = true
        errorMessage = ""
        
        // Sadece fotoğraf varsa boş string, yoksa metin
        let finalContent = postContent.isEmpty && selectedImage != nil ? " " : postContent
        let imageData = selectedImage?.jpegData(compressionQuality: 0.8)
        
        socialService.createPost(content: finalContent, imageData: imageData) { result in
            DispatchQueue.main.async {
                isPosting = false
                
                switch result {
                case .success(let newPost):
                    onPostCreated(newPost)
                    dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
}

#Preview {
    CreatePostView(onPostCreated: { _ in })
}
