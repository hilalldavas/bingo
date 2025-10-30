import SwiftUI

struct CreateStoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedImage: UIImage?
    @State private var showingImageSourcePicker = false
    @State private var showingCamera = false
    @State private var showingGallery = false
    @State private var isPosting = false
    
    let onStoryCreated: () -> Void
    
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
                    
                    Text("Yeni Hikaye")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: {
                        createStory()
                    }) {
                        Text("Paylaş")
                            .fontWeight(.semibold)
                            .foregroundColor(selectedImage == nil ? .secondary : .white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: selectedImage == nil ? [.gray, .gray] : [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(20)
                    }
                    .disabled(selectedImage == nil || isPosting)
                }
                .padding()
                
                Divider()
                
                // Content
                if let selectedImage = selectedImage {
                    // Preview
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                        
                        Button(action: {
                            self.selectedImage = nil
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.9))
                                    .frame(width: 40, height: 40)
                                    .shadow(radius: 8)
                                
                                Image(systemName: "xmark")
                                    .foregroundColor(.white)
                                    .fontWeight(.bold)
                            }
                            .padding(20)
                        }
                    }
                } else {
                    // Selection screen
                    VStack(spacing: 30) {
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple.opacity(0.2), .blue.opacity(0.15)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 50))
                                .foregroundColor(.purple)
                        }
                        
                        VStack(spacing: 12) {
                            Text("Hikaye Oluştur")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("24 saat boyunca görülebilecek bir fotoğraf paylaş")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        VStack(spacing: 15) {
                            Button(action: {
                                showingCamera = true
                            }) {
                                HStack {
                                    Image(systemName: "camera.fill")
                                        .font(.title3)
                                    Text("Kameradan Çek")
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                            }
                            
                            Button(action: {
                                showingGallery = true
                            }) {
                                HStack {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.title3)
                                    Text("Galeriden Seç")
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.purple)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 30)
                        
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
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
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        
                        Text("Hikaye paylaşılıyor...")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    .padding(40)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemBackground))
                            .shadow(radius: 20)
                    )
                }
            }
        }
    }
    
    private func createStory() {
        guard let imageData = selectedImage?.jpegData(compressionQuality: 0.8) else { return }
        
        isPosting = true
        
        SocialMediaService.shared.createStory(imageData: imageData) { result in
            DispatchQueue.main.async {
                isPosting = false
                
                switch result {
                case .success:
                    onStoryCreated()
                    dismiss()
                case .failure(let error):
                    print("DEBUG: Story oluşturma hatası: \(error.localizedDescription)")
                }
            }
        }
    }
}

