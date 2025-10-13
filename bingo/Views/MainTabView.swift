import SwiftUI
import FirebaseAuth

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Feed Tab
            FeedView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("Ana Sayfa")
                }
                .tag(0)
            
            // Search Tab
            SearchView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "magnifyingglass.circle.fill" : "magnifyingglass.circle")
                    Text("Keşfet")
                }
                .tag(1)
            
            // Create Post Tab
            CreatePostView(onPostCreated: {
                selectedTab = 0 // Switch to feed after creating post
            })
            .tabItem {
                Image(systemName: "plus.circle.fill")
                Text("Paylaş")
            }
            .tag(2)
            
            // Notifications Tab
            NotificationsView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "heart.fill" : "heart")
                    Text("Bildirimler")
                }
                .tag(3)
            
            // Profile Tab
            ProfileView()
                .tabItem {
                    Image(systemName: selectedTab == 4 ? "person.fill" : "person")
                    Text("Profil")
                }
                .tag(4)
        }
        .tint(.purple)
    }
}

// Placeholder views for tabs that aren't implemented yet
struct SearchView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "magnifyingglass.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                
                Text("Keşfet")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Bu özellik yakında gelecek!")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Keşfet")
        }
    }
}

struct NotificationsView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "heart.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                
                Text("Bildirimler")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Bu özellik yakında gelecek!")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Bildirimler")
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var profileViewModel = ProfileViewModel()
    @State private var showEditProfile = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    if profileViewModel.isLoading {
                        ProgressView("Profil yükleniyor...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let profile = profileViewModel.userProfile {
                        // Profile Header
                        VStack(spacing: 15) {
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
                            
                            Text(profile.fullName)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("@\(profile.username)")
                                .foregroundColor(.secondary)
                            
                            Text(profile.bio ?? "Henüz bio eklenmemiş")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            // Email bilgisi (sadece profil sahibi görebilir)
                            Text(profile.email)
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        
                        // Stats
                        HStack(spacing: 30) {
                            VStack {
                                Text("\(profile.posts)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Gönderiler")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack {
                                Text("\(profile.followers)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Takipçiler")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack {
                                Text("\(profile.following)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Takip Edilen")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // User Posts Section
                        if !profileViewModel.posts.isEmpty {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Gönderilerim")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .padding(.horizontal)
                                
                                LazyVStack(spacing: 15) {
                                    ForEach(profileViewModel.posts) { post in
                                        PostCardView(post: post, onRefresh: {
                                            profileViewModel.refreshUserPosts()
                                        })
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        Spacer(minLength: 100)
                        
                        // Action Buttons
                        VStack(spacing: 15) {
                            Button(action: {
                                showEditProfile = true
                            }) {
                                Text("Profili Düzenle")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                            
                            Button(action: {
                                authViewModel.logout()
                            }) {
                                Text("Çıkış Yap")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "person.circle")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            
                            Text("Profil yüklenemedi")
                                .font(.headline)
                            
                            if !profileViewModel.errorMessage.isEmpty {
                                Text(profileViewModel.errorMessage)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                            } else {
                                Text("Hata mesajı yok - debug için")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }
                            
                            // Debug bilgisi ekle
                            if let currentUser = Auth.auth().currentUser {
                                Text("User ID: \(currentUser.uid)")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                Text("Email: \(currentUser.email ?? "nil")")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                Text("Email Verified: \(currentUser.isEmailVerified ? "Yes" : "No")")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            
                            Button("Yeniden Dene") {
                                profileViewModel.refreshProfile()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                profileViewModel.refreshProfile()
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(profile: profileViewModel.userProfile) { updatedProfile in
                    profileViewModel.userProfile = updatedProfile
                    showEditProfile = false
                }
            }
        }
    }
}

#Preview {
    MainTabView()
}
