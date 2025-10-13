import SwiftUI
import FirebaseCore
import FirebaseAuth

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
                // Check if user is already logged in
                if let user = FirebaseAuth.Auth.auth().currentUser, user.isEmailVerified {
                    authViewModel.isLoggedIn = true
                }
            }
        }
    }
}
