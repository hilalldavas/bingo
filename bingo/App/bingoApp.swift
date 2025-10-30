import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseStorage

@main
struct bingoApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isLoggedIn {
                    MainTabView()
                        .environmentObject(authViewModel)
                } else if authViewModel.showVerificationScreen {
                    VerificationPendingView(vm: authViewModel)
                } else {
                    LoginView()
                        .environmentObject(authViewModel)
                }
            }
            .onAppear {
                print("DEBUG: App başlatıldı - Kullanıcı kontrolü yapılıyor")
                // Check if user is already logged in
                if let user = Auth.auth().currentUser {
                    print("DEBUG: Mevcut kullanıcı bulundu: \(user.email ?? "email yok")")
                    print("DEBUG: Email doğrulandı mı: \(user.isEmailVerified)")
                    if user.isEmailVerified {
                        authViewModel.isLoggedIn = true
                        // Firestore'da profil var mı kontrol et
                        authViewModel.validateUserProfile()
                    } else {
                        print("DEBUG: Email doğrulanmamış, giriş ekranına yönlendiriliyor")
                    }
                } else {
                    print("DEBUG: Mevcut kullanıcı bulunamadı, giriş ekranı gösteriliyor")
                }
            }
        }
    }
}
