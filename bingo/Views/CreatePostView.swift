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
    
    let onPostCreated: (PostModel) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("İptal") {
                        dismiss()
                    }
                    .foregroundColor(.purple)
                    
                    Spacer()
                    
                    Text("Yeni Post")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: {
                        createPost()
                    }) {
                        Text("Paylaş")
                            .fontWeight(.semibold)
                            .foregroundColor(postContent.isEmpty ? .secondary : .purple)
                    }
                    .disabled(postContent.isEmpty || isPosting)
                }
                .padding()
                
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
                        
                        // Text input
                        TextField("Ne düşünüyorsun?", text: $postContent, axis: .vertical)
                            .font(.body)
                            .lineLimit(10...15)
                        
                        // Image preview
                        if let selectedImage = selectedImage {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .cornerRadius(12)
                                    .frame(maxHeight: 300)
                                
                                Button(action: {
                                    self.selectedImage = nil
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                        .padding(8)
                                }
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
            }
            
            // Bottom toolbar
            VStack(spacing: 0) {
                Divider()
                
                HStack(spacing: 30) {
                    Button(action: {
                        showingImageSourcePicker = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.title3)
                            Text("Fotoğraf Ekle")
                                .font(.subheadline)
                        }
                        .foregroundColor(.purple)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .background(Color(.systemBackground))
        }
        .navigationBarHidden(true)
        .confirmationDialog("Fotoğraf Seç", isPresented: $showingImageSourcePicker, titleVisibility: .visible) {
            Button("Kameradan Çek") {
                showingCamera = true
            }
            Button("Galeriden Seç") {
                showingGallery = true
            }
            Button("İptal", role: .cancel) {}
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(image: $selectedImage, sourceType: .camera)
        }
        .sheet(isPresented: $showingGallery) {
            ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
        }
        .overlay(
            Group {
                if isPosting {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        
                        Text("Paylaşılıyor...")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    .padding(30)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(15)
                }
            }
        )
        .alert("Hata", isPresented: .constant(!errorMessage.isEmpty)) {
            Button("Tamam") {
                errorMessage = ""
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func createPost() {
        guard !postContent.isEmpty else { return }
        
        isPosting = true
        errorMessage = ""
        
        let imageData = selectedImage?.jpegData(compressionQuality: 0.8)
        
        socialService.createPost(content: postContent, imageData: imageData) { result in
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
