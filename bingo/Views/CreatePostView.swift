import SwiftUI
import PhotosUI

struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var socialService = SocialMediaService.shared
    @State private var postContent = ""
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingPhotoPicker = false
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
                        showingPhotoPicker = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.title3)
                            Text("Fotoğraf")
                                .font(.subheadline)
                        }
                        .foregroundColor(.purple)
                    }
                    
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "camera")
                                .font(.title3)
                            Text("Kamera")
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
        .photosPicker(isPresented: $showingPhotoPicker, selection: Binding<PhotosPickerItem?>(
            get: { nil },
            set: { item in
                if let item = item {
                    loadImage(from: item)
                }
            }
        ))
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage)
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
    
    private func loadImage(from item: PhotosPickerItem) {
        item.loadTransferable(type: Data.self) { result in
            switch result {
            case .success(let data):
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.selectedImage = image
                    }
                }
            case .failure(let error):
                print("Error loading image: \(error)")
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    CreatePostView(onPostCreated: { _ in })
}
