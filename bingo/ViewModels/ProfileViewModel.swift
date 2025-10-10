import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

class ProfileViewModel: ObservableObject {
    @Published var userProfile: UserProfileModel?
    @Published var posts: [PostModel] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let socialMediaService = SocialMediaService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadCurrentUserProfile()
    }
    
    func loadCurrentUserProfile() {
        guard let currentUser = Auth.auth().currentUser else {
            errorMessage = "Kullanıcı giriş yapmamış"
            return
        }
        
        print("DEBUG: Kullanıcı ID: \(currentUser.uid)")
        print("DEBUG: Kullanıcı Email: \(currentUser.email ?? "nil")")
        
        isLoading = true
        errorMessage = ""
        
        // Kullanıcı profilini çek
        socialMediaService.fetchUserProfile(userId: currentUser.uid) { [weak self] result in
            DispatchQueue.main.async {
                // isLoading durumunu burada kapatmayacağız; profil yoksa
                // createDefaultProfile sırasında da yükleniyor göstermek istiyoruz
                switch result {
                case .success(let profile):
                    if let profile = profile {
                        print("DEBUG: Profil bulundu: \(profile.fullName)")
                        self?.isLoading = false
                        self?.userProfile = profile
                        self?.loadUserPosts()
                    } else {
                        print("DEBUG: Profil bulunamadı, varsayılan profil oluşturuluyor...")
                        // Profil yoksa varsayılan profil oluştur
                        self?.createDefaultProfile()
                    }
                case .failure(let error):
                    self?.isLoading = false
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func createDefaultProfile() {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        isLoading = true
        
        // Email'den kullanıcı adı oluştur
        let email = currentUser.email ?? "kullanici@example.com"
        let usernameFromEmail = email.components(separatedBy: "@").first ?? "kullanici"
        let fullNameFromEmail = usernameFromEmail.capitalized
        
        let defaultProfile = UserProfileModel(
            email: email,
            username: usernameFromEmail,
            fullName: fullNameFromEmail,
            bio: "Bingo Social'da yeni bir yolculuğa başladım! 🎯"
        )
        
        var profile = defaultProfile
        profile.id = currentUser.uid
        
        socialMediaService.createUserProfile(userProfile: profile) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.isLoading = false
                    self?.userProfile = profile
                    self?.loadUserPosts()
                case .failure(let error):
                    self?.isLoading = false
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func loadUserPosts() {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        // Kullanıcının postlarını çek
        socialMediaService.fetchPosts { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let allPosts):
                    // Sadece bu kullanıcının postlarını filtrele
                    self?.posts = allPosts.filter { $0.authorId == currentUser.uid }
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func refreshProfile() {
        loadCurrentUserProfile()
    }
    
    func updateProfile(fullName: String, username: String, bio: String, completion: @escaping (Bool) -> Void) {
        guard var profile = userProfile else {
            completion(false)
            return
        }
        
        profile.fullName = fullName
        profile.username = username
        profile.bio = bio
        
        socialMediaService.createUserProfile(userProfile: profile) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.userProfile = profile
                    completion(true)
                case .failure:
                    completion(false)
                }
            }
        }
    }
}


