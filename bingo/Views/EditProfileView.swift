import SwiftUI
import FirebaseAuth
import PhotosUI

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
    @State private var showingPhotoPicker = false
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
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else if let profileImageURL = profile?.profileImageURL, !profileImageURL.isEmpty {
                            // Mevcut profil fotoğrafı
                            AsyncImage(url: URL(string: profileImageURL)) { image in
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
                                        ProgressView()
                                    )
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                        } else {
                            // Varsayılan avatar
                            Circle()
                                .fill(LinearGradient(
                                    colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 40))
                                )
                        }
                        
                        // Yükleniyor göstergesi
                        if isUploadingImage {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    ProgressView()
                                        .tint(.white)
                                )
                        }
                    }
                    
                    Button(action: {
                        showingPhotoPicker = true
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "camera.fill")
                            Text("Profil Fotoğrafı Değiştir")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
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
            .photosPicker(isPresented: $showingPhotoPicker, selection: Binding<PhotosPickerItem?>(
                get: { nil },
                set: { item in
                    if let item = item {
                        loadImage(from: item)
                    }
                }
            ))
        }
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
                print("DEBUG: EditProfileView - Resim yükleme hatası: \(error)")
                DispatchQueue.main.async {
                    errorMessage = "Resim yüklenirken hata oluştu"
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

