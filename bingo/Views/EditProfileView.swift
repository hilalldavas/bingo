import SwiftUI
import FirebaseAuth

struct EditProfileView: View {
    let profile: UserProfileModel?
    let onSave: (UserProfileModel) -> Void
    
    @State private var fullName: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var isLoading = false
    @State private var isCheckingUsername = false
    @State private var errorMessage = ""
    @State private var usernameMessage = ""
    @State private var originalUsername = ""
    @State private var selectedImage: UIImage?
    @State private var showingImageSourcePicker = false
    @State private var showingCamera = false
    @State private var showingGallery = false
    @State private var isUploadingImage = false
    
    @Environment(\.dismiss) private var dismiss
    
    private let socialMediaService = SocialMediaService.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Profile Picture Section
                VStack(spacing: 15) {
                    ZStack {
                        if let selectedImage = selectedImage {
                            // Yeni seçilen resim
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.blue, lineWidth: 3)
                                )
                        } else if let profileImageURL = profile?.profileImageURL, !profileImageURL.isEmpty {
                            // Mevcut profil fotoğrafı
                            AsyncImage(url: URL(string: profileImageURL)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                        )
                                case .failure(_):
                                    defaultAvatar()
                                case .empty:
                                    defaultAvatar()
                                        .overlay(
                                            ProgressView()
                                        )
                                @unknown default:
                                    defaultAvatar()
                                }
                            }
                        } else {
                            defaultAvatar()
                        }
                        
                        // Yükleniyor göstergesi
                        if isUploadingImage {
                            Circle()
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 120, height: 120)
                                .overlay(
                                    VStack(spacing: 8) {
                                        ProgressView()
                                            .tint(.white)
                                        Text("Yükleniyor...")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                )
                        }
                    }
                    
                    Button(action: {
                        showingImageSourcePicker = true
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "camera.fill")
                            Text("Profil Fotoğrafı Değiştir")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(20)
                    }
                    .disabled(isUploadingImage)
                }
                .padding(.top)
                
                // Form Fields
                VStack(spacing: 15) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Ad Soyad")
                            .font(.headline)
                        TextField("Ad Soyad", text: $fullName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Kullanıcı Adı")
                            .font(.headline)
                        HStack {
                            TextField("Kullanıcı Adı", text: $username)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: username) {
                                    checkUsernameAvailability()
                                }
                            
                            if isCheckingUsername {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    .scaleEffect(0.8)
                            }
                        }
                        
                        if !usernameMessage.isEmpty {
                            Text(usernameMessage)
                                .font(.caption)
                                .foregroundColor(usernameMessage.contains("✅") ? .green : .red)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Bio")
                            .font(.headline)
                        TextField("Hakkımda...", text: $bio, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3...6)
                    }
                }
                .padding(.horizontal)
                
                // Error Message
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Save Button
                Button(action: saveProfile) {
                    if isLoading {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("Kaydediliyor...")
                        }
                    } else {
                        Text("Kaydet")
                    }
                }
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
                .padding(.horizontal)
                .disabled(isLoading || fullName.isEmpty || username.isEmpty)
            }
            .navigationTitle("Profili Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCurrentProfile()
            }
            .confirmationDialog("Profil Fotoğrafı Seç", isPresented: $showingImageSourcePicker, titleVisibility: .visible) {
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
        }
    }
    
    // Helper function for default avatar
    @ViewBuilder
    private func defaultAvatar() -> some View {
        Circle()
            .fill(LinearGradient(
                colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: 120, height: 120)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 50))
            )
    }
    
    private func loadCurrentProfile() {
        if let profile = profile {
            fullName = profile.fullName
            username = profile.username
            originalUsername = profile.username
            bio = profile.bio ?? ""
        }
    }
    
    private func saveProfile() {
        guard !fullName.isEmpty && !username.isEmpty else {
            errorMessage = "Ad soyad ve kullanıcı adı zorunludur"
            return
        }
        
        // Username validation
        if username.count < 3 {
            errorMessage = "Kullanıcı adı en az 3 karakter olmalıdır"
            return
        }
        
        if username.contains(" ") {
            errorMessage = "Kullanıcı adında boşluk olamaz"
            return
        }
        
        let regex = "^[a-zA-Z0-9._-]+$"
        if !NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: username) {
            errorMessage = "Kullanıcı adı sadece harf, rakam, nokta, tire ve alt çizgi içerebilir"
            return
        }
        
        guard let currentUser = Auth.auth().currentUser else {
            errorMessage = "Kullanıcı giriş yapmamış"
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        // Eğer kullanıcı adı değiştiyse kontrol et
        if username != originalUsername {
            isCheckingUsername = true
            socialMediaService.checkUsernameAvailability(username: username, currentUserId: currentUser.uid) { result in
                DispatchQueue.main.async {
                    isCheckingUsername = false
                    switch result {
                    case .success(let isAvailable):
                        if isAvailable {
                            performProfileUpdate()
                        } else {
                            errorMessage = "Bu kullanıcı adı zaten alınmış. Lütfen başka bir kullanıcı adı seçin."
                            isLoading = false
                        }
                    case .failure(let error):
                        errorMessage = "Kullanıcı adı kontrolü başarısız: \(error.localizedDescription)"
                        isLoading = false
                    }
                }
            }
        } else {
            // Kullanıcı adı değişmemişse direkt güncelle
            performProfileUpdate()
        }
    }
    
    private func performProfileUpdate() {
        guard var updatedProfile = profile else {
            errorMessage = "Profil bilgileri bulunamadı"
            isLoading = false
            return
        }
        
        guard let currentUser = Auth.auth().currentUser else {
            errorMessage = "Kullanıcı giriş yapmamış"
            isLoading = false
            return
        }
        
        // Eğer yeni resim seçildiyse, önce resmi yükle
        if let newImage = selectedImage {
            isUploadingImage = true
            socialMediaService.uploadProfileImage(newImage, userId: currentUser.uid) { [self] result in
                DispatchQueue.main.async {
                    isUploadingImage = false
                    switch result {
                    case .success(let imageURL):
                        // Resim yüklendi, profil verisini güncelle
                        updatedProfile.profileImageURL = imageURL
                        updateProfileData(updatedProfile)
                    case .failure(let error):
                        errorMessage = "Resim yüklenirken hata oluştu: \(error.localizedDescription)"
                        isLoading = false
                    }
                }
            }
        } else {
            // Resim yoksa direkt profil verisini güncelle
            updateProfileData(updatedProfile)
        }
    }
    
    private func updateProfileData(_ updatedProfile: UserProfileModel) {
        var profile = updatedProfile
        
        // Update profile data
        profile.fullName = fullName
        profile.username = username
        profile.bio = bio
        
        print("DEBUG: updateProfileData - Profil güncelleniyor: \(profile.profileImageURL ?? "nil")")
        
        // Update in Firebase
        socialMediaService.updateUserProfile(userProfile: profile) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success:
                    onSave(profile)
                    dismiss()
                case .failure(let error):
                    errorMessage = "Profil güncellenirken hata oluştu: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func checkUsernameAvailability() {
        // Debounce the API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Eğer kullanıcı adı çok kısa veya boşsa mesajı temizle
            if username.count < 3 {
                usernameMessage = ""
                return
            }
            
            // Eğer boşluk varsa hata göster
            if username.contains(" ") {
                usernameMessage = "❌ Kullanıcı adında boşluk olamaz"
                return
            }
            
            // Format kontrolü
            let regex = "^[a-zA-Z0-9._-]+$"
            if !NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: username) {
                usernameMessage = "❌ Sadece harf, rakam, nokta, tire ve alt çizgi kullanılabilir"
                return
            }
            
            guard let currentUser = Auth.auth().currentUser else { 
                usernameMessage = "❌ Kullanıcı giriş yapmamış"
                return 
            }
            
            // Eğer kullanıcı adı orijinal ile aynıysa, kullanılabilir göster
            if username == originalUsername {
                usernameMessage = "✅ Mevcut kullanıcı adınız"
                return
            }
            
            isCheckingUsername = true
            usernameMessage = "Kontrol ediliyor..."
            
            socialMediaService.checkUsernameAvailability(username: username, currentUserId: currentUser.uid) { result in
                DispatchQueue.main.async {
                    isCheckingUsername = false
                    switch result {
                    case .success(let isAvailable):
                        if isAvailable {
                            usernameMessage = "✅ Bu kullanıcı adı kullanılabilir"
                        } else {
                            usernameMessage = "❌ Bu kullanıcı adı zaten alınmış"
                        }
                    case .failure(let error):
                        print("DEBUG: EditProfileView - Username kontrol hatası: \(error.localizedDescription)")
                        usernameMessage = "❌ Kontrol edilemedi: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}

#Preview {
    EditProfileView(profile: UserProfileModel(
        email: "test@example.com",
        username: "testuser",
        fullName: "Test User",
        bio: "Test bio"
    )) { _ in }
}

