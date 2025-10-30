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
            CreatePostView(onPostCreated: { _ in
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
                .onAppear {
                    // Profil sekmesine her gelindiğinde yenile
                    print("DEBUG: Profil sekmesi açıldı, veriler yenileniyor")
                }
        }
        .tint(.purple)
        .onAppear {
            // Kullanıcı profili Firestore'da var mı kontrol et
            authViewModel.validateUserProfile()
        }
    }
}

// Placeholder views for tabs that aren't implemented yet
struct SearchView: View {
    @StateObject private var socialService = SocialMediaService.shared
    @State private var searchText = ""
    @State private var searchResults: [UserProfileModel] = []
    @State private var trendingPosts: [PostModel] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Kullanıcı ara...", text: $searchText)
                            .textFieldStyle(.plain)
                            .autocapitalization(.none)
                            .onChange(of: searchText) { _, newValue in
                                searchUsers(query: newValue)
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                searchResults = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding()
                    
                    // Search results veya trending
                    if !searchText.isEmpty {
                        // Search results
                        if searchResults.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "person.2.slash")
                                    .font(.system(size: 50))
                                    .foregroundColor(.secondary)
                                
                                Text("Kullanıcı bulunamadı")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 60)
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(searchResults) { user in
                                    UserSearchResultView(user: user)
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                    
                                    Divider()
                                }
                            }
                        }
                    } else {
                        // Trending posts (Instagram Keşfet gibi)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Popüler İçerikler")
                                .font(.headline)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 2),
                                GridItem(.flexible(), spacing: 2),
                                GridItem(.flexible(), spacing: 2)
                            ], spacing: 2) {
                                ForEach(trendingPosts) { post in
                                    PostGridItem(post: post)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Keşfet")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            loadTrendingPosts()
        }
    }
    
    private func searchUsers(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        // Username ve fullName'de ara
        socialService.searchUsers(query: query) { result in
            DispatchQueue.main.async {
                isSearching = false
                switch result {
                case .success(let users):
                    searchResults = users
                case .failure(let error):
                    print("DEBUG: Arama hatası: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadTrendingPosts() {
        // En çok beğenilen postları getir
        socialService.fetchTrendingPosts { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let posts):
                    trendingPosts = posts
                case .failure(let error):
                    print("DEBUG: Trending posts hatası: \(error.localizedDescription)")
                }
            }
        }
    }
}

// User Search Result
struct UserSearchResultView: View {
    let user: UserProfileModel
    @State private var showUserProfile = false
    
    var body: some View {
        Button(action: {
            showUserProfile = true
        }) {
            HStack(spacing: 12) {
                // Profile photo
                AsyncImage(url: URL(string: user.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.fullName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("@\(user.username)")
                        .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showUserProfile) {
            if let currentUserId = Auth.auth().currentUser?.uid, let userId = user.id {
                UserProfileView(userId: userId, currentUserId: currentUserId)
            }
        }
    }
}

struct NotificationsView: View {
    @StateObject private var socialService = SocialMediaService.shared
    @State private var notifications: [NotificationModel] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                if isLoading {
                    ProgressView("Yükleniyor...")
                        .padding()
                } else if notifications.isEmpty {
            VStack(spacing: 20) {
                        Image(systemName: "bell.slash")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                
                        Text("Henüz bildirim yok")
                            .font(.title3)
                    .fontWeight(.bold)
                
                        Text("Etkileşimler burada görünecek")
                    .foregroundColor(.secondary)
                    }
                    .padding(.top, 100)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(notifications) { notification in
                            NotificationRowView(notification: notification)
                            Divider()
                        }
                    }
                }
            }
            .navigationTitle("Bildirimler")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            loadNotifications()
        }
        .refreshable {
            loadNotifications()
        }
    }
    
    private func loadNotifications() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        socialService.fetchNotifications(userId: currentUserId) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let notifs):
                    notifications = notifs
                case .failure(let error):
                    print("DEBUG: Bildirim yükleme hatası: \(error.localizedDescription)")
                }
            }
        }
    }
}

// Notification Row
struct NotificationRowView: View {
    let notification: NotificationModel
    @State private var showUserProfile = false
    @State private var showPost = false
    
    var body: some View {
        Button(action: {
            handleTap()
        }) {
            HStack(spacing: 12) {
                // Profile photo
                AsyncImage(url: URL(string: notification.fromUserProfileImage ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 45, height: 45)
                .clipShape(Circle())
                .overlay(
                    // Notification icon badge
                    Circle()
                        .fill(notificationColor)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Image(systemName: notification.icon)
                                .font(.caption2)
                                .foregroundColor(.white)
                        )
                        .offset(x: 16, y: 16)
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.message)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .fontWeight(notification.isRead ? .regular : .semibold)
                    
                    Text(formatTimestamp(notification.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !notification.isRead {
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 8, height: 8)
                }
            }
            .padding()
            .background(notification.isRead ? Color.clear : Color.purple.opacity(0.05))
        }
        .sheet(isPresented: $showUserProfile) {
            if let currentUserId = Auth.auth().currentUser?.uid {
                UserProfileView(userId: notification.fromUserId, currentUserId: currentUserId)
            }
        }
    }
    
    private var notificationColor: Color {
        switch notification.type {
        case .like: return .red
        case .comment: return .purple
        case .follow: return .blue
        }
    }
    
    private func handleTap() {
        // Bildirimi okundu olarak işaretle
        if let currentUserId = Auth.auth().currentUser?.uid, let notificationId = notification.id {
            SocialMediaService.shared.markNotificationAsRead(userId: currentUserId, notificationId: notificationId) { _ in }
        }
        
        // Bildirim tipine göre yönlendir
        switch notification.type {
        case .follow:
            showUserProfile = true
        case .like, .comment:
            if notification.postId != nil {
                showPost = true
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

enum ProfilePostFilter: String, CaseIterable {
    case all = "Tümü"
    case photos = "Fotoğraflar"
    case text = "Metinler"
}

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var profileViewModel = ProfileViewModel()
    @State private var showEditProfile = false
    @State private var showDeleteConfirmation = false
    @State private var showDeactivateConfirmation = false
    @State private var isDeletingAccount = false
    @State private var isDeactivatingAccount = false
    @State private var deleteErrorMessage = ""
    @State private var showDeleteError = false
    @State private var showAccountMenu = false
    @State private var selectedFilter: ProfilePostFilter = .all
    
    private var filteredPosts: [PostModel] {
        switch selectedFilter {
        case .all:
            return profileViewModel.posts
        case .photos:
            return profileViewModel.posts.filter { $0.imageURL != nil }
        case .text:
            return profileViewModel.posts.filter { $0.imageURL == nil }
        }
    }
    
    private var emptyStateIcon: String {
        switch selectedFilter {
        case .all: return "photo.on.rectangle.angled"
        case .photos: return "photo.fill.on.rectangle.fill"
        case .text: return "text.quote"
        }
    }
    
    private var emptyStateTitle: String {
        switch selectedFilter {
        case .all: return "Henüz paylaşım yok"
        case .photos: return "Henüz fotoğraf yok"
        case .text: return "Henüz metin postu yok"
        }
    }
    
    private var emptyStateMessage: String {
        switch selectedFilter {
        case .all: return "İlk postunu paylaş!"
        case .photos: return "Fotoğraflı post paylaş!"
        case .text: return "Düşüncelerini paylaş!"
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    if profileViewModel.isLoading {
                        ProgressView("Profil yükleniyor...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let profile = profileViewModel.userProfile {
                        VStack(spacing: 0) {
                            // INSTAGRAM STYLE HEADER - Kompakt ve organize
                            VStack(spacing: 16) {
                                // Full Name Header + Menu
                                HStack {
                                    Text(profile.fullName)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    
                                    Spacer()
                                    
                                    // Menü butonu
                                    Menu {
                                        // Profil Düzenle
                                        Button(action: {
                                            showEditProfile = true
                                        }) {
                                            Label("Profil Düzenle", systemImage: "pencil.circle")
                                        }
                                        
                                        Divider()
                                        
                                        // Hesabı Dondur
                                        Button(role: .destructive, action: {
                                            showDeactivateConfirmation = true
                                        }) {
                                            Label("Hesabı Dondur (30 gün)", systemImage: "pause.circle")
                                        }
                                        
                                        // Hesabı Sil
                                        Button(role: .destructive, action: {
                                            showDeleteConfirmation = true
                                        }) {
                                            Label("Hesabı Kalıcı Sil", systemImage: "trash")
                                        }
                                        
                                        Divider()
                                        
                                        // Çıkış Yap
                                        Button(role: .destructive, action: {
                                            authViewModel.logout()
                                        }) {
                                            Label("Çıkış Yap", systemImage: "rectangle.portrait.and.arrow.right")
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .font(.title3)
                                            .foregroundColor(.primary)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, 8)
                                
                                // Profil fotoğrafı + İstatistikler (yan yana)
                                HStack(spacing: 20) {
                            // Profil Fotoğrafı
                            if let profileImageURL = profile.profileImageURL, !profileImageURL.isEmpty {
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
                                                .overlay(ProgressView())
                                        }
                                        .frame(width: 85, height: 85)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [.purple.opacity(0.5), .blue.opacity(0.4)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 2
                                                )
                                        )
                            } else {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                            .frame(width: 85, height: 85)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.white)
                                                    .font(.system(size: 35))
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(
                                                        LinearGradient(
                                                            colors: [.purple.opacity(0.5), .blue.opacity(0.4)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 2
                                                    )
                                            )
                                    }
                                    
                                    // İstatistikler - Instagram style (kompakt)
                                    HStack(spacing: 0) {
                                        StatView(count: profileViewModel.posts.count, label: "gönderi")
                                        StatView(count: profile.followers, label: "takipçi")
                                        StatView(count: profile.following, label: "takip")
                                    }
                                }
                                .padding(.horizontal)
                                
                                // Username ve Bio - Instagram style
                                VStack(alignment: .leading, spacing: 4) {
                            Text("@\(profile.username)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    if let bio = profile.bio, !bio.isEmpty {
                                        Text(bio)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            
                                // Düzenle Butonu - Instagram style
                                Button(action: {
                                    showEditProfile = true
                                }) {
                                    Text("Profili Düzenle")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                }
                                .padding(.horizontal)
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                            
                            Divider()
                                .padding(.bottom, 8)
                        
                            // Gönderiler Grid - Instagram style
                            VStack(spacing: 0) {
                                // Tab Bar - Instagram style
                                HStack(spacing: 0) {
                                    // Tümü
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedFilter = .all
                                        }
                                    }) {
                                        VStack(spacing: 8) {
                                            Image(systemName: "square.grid.3x3.fill")
                                                .font(.title3)
                                                .foregroundColor(selectedFilter == .all ? .primary : .secondary)
                                            
                                            Rectangle()
                                                .fill(selectedFilter == .all ? Color.primary : Color.clear)
                                                .frame(height: 1)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    
                                    // Fotoğraflar
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedFilter = .photos
                                        }
                                    }) {
                                        VStack(spacing: 8) {
                                            Image(systemName: "photo.fill")
                                                .font(.title3)
                                                .foregroundColor(selectedFilter == .photos ? .primary : .secondary)
                                            
                                            Rectangle()
                                                .fill(selectedFilter == .photos ? Color.primary : Color.clear)
                                                .frame(height: 1)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    
                                    // Metinler
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedFilter = .text
                                        }
                                    }) {
                                        VStack(spacing: 8) {
                                            Image(systemName: "text.quote")
                                                .font(.title3)
                                                .foregroundColor(selectedFilter == .text ? .primary : .secondary)
                                            
                                            Rectangle()
                                                .fill(selectedFilter == .text ? Color.primary : Color.clear)
                                                .frame(height: 1)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .padding(.top, 8)
                                
                                Divider()
                                
                                if filteredPosts.isEmpty {
                                    // Boş durum - filter'a göre dinamik
                                    VStack(spacing: 16) {
                                        Image(systemName: emptyStateIcon)
                                            .font(.system(size: 50))
                                            .foregroundColor(.secondary)
                                        
                                        Text(emptyStateTitle)
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                        
                                        Text(emptyStateMessage)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary.opacity(0.7))
                                    }
                                    .padding(.vertical, 60)
                                } else {
                                    // Grid Layout
                                    LazyVGrid(columns: [
                                        GridItem(.flexible(), spacing: 2),
                                        GridItem(.flexible(), spacing: 2),
                                        GridItem(.flexible(), spacing: 2)
                                    ], spacing: 2) {
                                        ForEach(filteredPosts) { post in
                                            PostGridItem(post: post)
                                        }
                                    }
                                }
                            }
                        }
                        
                        Spacer(minLength: 30)
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
            .navigationBarHidden(true)
            .refreshable {
                profileViewModel.refreshProfile()
            }
            .onAppear {
                // Profil sayfası açıldığında postları yenile
                profileViewModel.refreshUserPosts()
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(profile: profileViewModel.userProfile) { updatedProfile in
                    profileViewModel.userProfile = updatedProfile
                    profileViewModel.refreshProfile() // Firestore'dan güncel veriyi çek
                    showEditProfile = false
                }
            }
            .alert("Hesabı Dondur", isPresented: $showDeactivateConfirmation) {
                Button("İptal", role: .cancel) { }
                Button("Dondur", role: .destructive) {
                    deactivateAccount()
                }
            } message: {
                Text("Hesabınız 30 gün boyunca dondurulacak. Bu süre içinde profiliniz ve postlarınız gizlenecek. 30 gün içinde tekrar giriş yaparsanız tüm verileriniz geri gelecek. 30 gün sonra hesabınız kalıcı olarak silinecek!")
            }
            .alert("Hesabı Kalıcı Sil", isPresented: $showDeleteConfirmation) {
                Button("İptal", role: .cancel) { }
                Button("Sil", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("Hesabınız, tüm postlarınız, yorumlarınız ve beğenileriniz KALICI OLARAK silinecek. Bu işlem GERİ ALINAMAZ!")
            }
            .alert("Hata", isPresented: $showDeleteError) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(deleteErrorMessage)
            }
            .overlay {
                if isDeletingAccount || isDeactivatingAccount {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            
                            Text(isDeletingAccount ? "Hesap kalıcı olarak siliniyor..." : "Hesap dondurulyor...")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        .padding(30)
                        .background(Color(.systemBackground).opacity(0.95))
                        .cornerRadius(20)
                        .shadow(radius: 10)
                    }
                }
            }
        }
    }
    
    private func deactivateAccount() {
        guard let currentUser = Auth.auth().currentUser else {
            print("DEBUG: Kullanıcı bulunamadı")
            return
        }
        
        isDeactivatingAccount = true
        deleteErrorMessage = ""
        
        print("DEBUG: Hesap dondurma başlatıldı - UserID: \(currentUser.uid)")
        
        SocialMediaService.shared.deactivateAccount(userId: currentUser.uid) { [self] result in
            DispatchQueue.main.async {
                isDeactivatingAccount = false
                
                switch result {
                case .success:
                    print("DEBUG: ✅ Hesap başarıyla donduruldu")
                    authViewModel.infoMessage = "Hesabınız 30 gün süreyle donduruldu. Bu süre içinde tekrar giriş yaparsanız hesabınız aktifleşecek."
                    authViewModel.logout()
                    
                case .failure(let error):
                    print("DEBUG: ❌ Hesap dondurma hatası: \(error.localizedDescription)")
                    deleteErrorMessage = "Hesap dondurulamadı: \(error.localizedDescription)"
                    showDeleteError = true
                }
            }
        }
    }
    
    private func deleteAccount() {
        guard let currentUser = Auth.auth().currentUser else { 
            print("DEBUG: Kullanıcı bulunamadı")
            return 
        }
        
        isDeletingAccount = true
        deleteErrorMessage = ""
        
        print("DEBUG: Hesap silme başlatıldı - UserID: \(currentUser.uid)")
        
        // Önce Firestore'dan kullanıcı verilerini sil (posts, comments, likes, profile)
        SocialMediaService.shared.deleteUserAndAllContent(userId: currentUser.uid) { [self] result in
            switch result {
            case .success:
                print("DEBUG: ✅ Firestore verileri silindi, şimdi Firebase Auth kullanıcısı siliniyor...")
                
                // Sonra Firebase Auth'dan kullanıcıyı kalıcı olarak sil
                currentUser.delete { error in
                    DispatchQueue.main.async {
                        isDeletingAccount = false
                        
                        if let error = error {
                            print("DEBUG: ❌ Firebase Auth silme hatası: \(error.localizedDescription)")
                            
                            // Özel hata durumları
                            if (error as NSError).code == 17014 {
                                // Recent login required - Kullanıcının tekrar giriş yapması gerekiyor
                                deleteErrorMessage = "Güvenlik nedeniyle, hesabınızı silmek için önce çıkış yapıp tekrar giriş yapmanız gerekiyor."
                            } else {
                                deleteErrorMessage = "Hesap silinemedi: \(error.localizedDescription)"
                            }
                            showDeleteError = true
                        } else {
                            print("DEBUG: ✅ Firebase Auth kullanıcısı silindi!")
                            print("DEBUG: Hesap tamamen silindi - Giriş ekranına yönlendiriliyor...")
                            
                            // State'i temizle ve giriş ekranına dön
                            // Kullanıcı zaten Auth'dan silindiği için logout() gereksiz, sadece state temizle
                            authViewModel.isLoggedIn = false
                            authViewModel.email = ""
                            authViewModel.password = ""
                            authViewModel.fullName = ""
                            authViewModel.username = ""
                            authViewModel.errorMessage = ""
                            authViewModel.infoMessage = "Hesabınız başarıyla silindi."
                            authViewModel.showVerificationScreen = false
                        }
                    }
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    isDeletingAccount = false
                    print("DEBUG: ❌ Firestore silme hatası: \(error.localizedDescription)")
                    deleteErrorMessage = "Veriler silinemedi: \(error.localizedDescription)"
                    showDeleteError = true
                }
            }
        }
    }
}

// MARK: - Stat View (Instagram style)
struct StatView: View {
    let count: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.headline)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Post Grid Item (Instagram style)
struct PostGridItem: View {
    let post: PostModel
    @State private var showPostDetail = false
    
    var body: some View {
        Button(action: {
            showPostDetail = true
        }) {
            ZStack(alignment: .topLeading) {
                if let imageURL = post.imageURL {
                    // Fotoğraflı post
                    AsyncImage(url: URL(string: imageURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .overlay(
                                ProgressView()
                                    .tint(.purple)
                            )
                    }
                    .frame(width: (UIScreen.main.bounds.width - 4) / 3, height: (UIScreen.main.bounds.width - 4) / 3)
                    .clipped()
                } else {
                    // Sadece metin postu
                    ZStack {
                        LinearGradient(
                            colors: [.purple.opacity(0.15), .blue.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        
                        VStack(spacing: 8) {
                            Image(systemName: "quote.bubble.fill")
                                .font(.title2)
                                .foregroundColor(.purple.opacity(0.7))
                            
                            Text(post.content)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .lineLimit(4)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }
                    }
                    .frame(width: (UIScreen.main.bounds.width - 4) / 3, height: (UIScreen.main.bounds.width - 4) / 3)
                }
                
                // Etkileşim badge'leri (isteğe bağlı)
                if post.likes > 0 || post.comments > 0 {
                    HStack(spacing: 4) {
                        if post.likes > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "heart.fill")
                                    .font(.caption2)
                                Text("\(post.likes)")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                        }
                        
                        if post.comments > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "message.fill")
                                    .font(.caption2)
                                Text("\(post.comments)")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    .padding(6)
                }
            }
        }
        .sheet(isPresented: $showPostDetail) {
            PostDetailView(post: post)
        }
    }
}

// MARK: - Post Detail View (Premium Instagram Style)
struct PostDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let post: PostModel
    @State private var isLiked = false
    @State private var likeCount = 0
    @State private var commentCount = 0
    @State private var showComments = false
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                // Background
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Header - Author Info
                        HStack(spacing: 12) {
                            // Profile photo
                            AsyncImage(url: URL(string: post.authorProfileImage ?? "")) { image in
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
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.white)
                                    )
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(post.authorName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Text(formatTimestamp(post.timestamp))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Kapat") {
                                dismiss()
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                        }
                        .padding()
                        
                        Divider()
                        
                        // Post Image - Full width
                        if let imageURL = post.imageURL {
                            AsyncImage(url: URL(string: imageURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color(.systemGray5))
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay(
                                        ProgressView()
                                            .tint(.purple)
                                    )
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
                        // Action Buttons - Instagram style (SOLA YASLI)
                        VStack(spacing: 0) {
                            HStack(spacing: 20) {
                                // Like button
                                Button(action: {
                                    toggleLike()
                                }) {
                                    Image(systemName: isLiked ? "heart.fill" : "heart")
                                        .font(.title2)
                                        .foregroundColor(isLiked ? .red : .primary)
                                }
                                
                                // Comment button
                                Button(action: {
                                    showComments = true
                                }) {
                                    Image(systemName: "message")
                                        .font(.title2)
                                        .foregroundColor(.primary)
                                }
                                
                                // Share button
                                Button(action: {}) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.title2)
                                        .foregroundColor(.primary)
                                }
                                
                                Spacer()
                            }
                            .padding()
                            
                            // Like & Comment counts - Instagram style
                            if likeCount > 0 || commentCount > 0 {
                                HStack(spacing: 4) {
                                    if likeCount > 0 {
                                        Text("\(likeCount) beğeni")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                    }
                                    
                                    if likeCount > 0 && commentCount > 0 {
                                        Text("•")
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if commentCount > 0 {
                                        Text("\(commentCount) yorum")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 8)
                            }
                            
                            Divider()
                        }
                        
                        // Post Content - Instagram caption style (SOLA YASLI)
                        if !post.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            HStack(alignment: .top, spacing: 8) {
                                // Mini profile photo
                                AsyncImage(url: URL(string: post.authorProfileImage ?? "")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle()
                                        .fill(Color.purple.opacity(0.2))
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                        )
                                }
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                                
                                // Author name + content (Instagram style)
                                HStack(alignment: .top, spacing: 4) {
                                    Text(post.authorName)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    Text(post.content)
                                        .font(.subheadline)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                        }
                        
                        Spacer(minLength: 50)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showComments) {
                CommentsView(postId: post.id ?? "") {
                    commentCount += 1
                }
            }
            .onAppear {
                isLiked = post.isLikedByUser
                likeCount = post.likes
                commentCount = post.comments
            }
        }
    }
    
    private func toggleLike() {
        guard let postId = post.id else { return }
        
        let originalLiked = isLiked
        let originalCount = likeCount
        
        // Optimistic update
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1
        
        SocialMediaService.shared.likePost(postId: postId) { result in
            DispatchQueue.main.async {
                switch result {
                case .failure:
                    // Revert on error
                    isLiked = originalLiked
                    likeCount = originalCount
                case .success(let updatedPost):
                    // Update with real data
                    isLiked = updatedPost.isLikedByUser
                    likeCount = updatedPost.likes
                }
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    MainTabView()
}
