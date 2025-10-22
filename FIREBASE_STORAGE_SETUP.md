# Firebase Storage Kurulum Talimatları

Firebase Storage entegrasyonu başarıyla kodlandı! Şimdi projeyi çalıştırmak için aşağıdaki adımları takip edin:

## 📦 1. Firebase Storage Paketini Xcode'a Ekle

1. **Xcode'da projeyi açın**
2. **File > Add Package Dependencies** menüsüne gidin
3. Aşağıdaki URL'yi girin:
   ```
   https://github.com/firebase/firebase-ios-sdk
   ```
4. Version: `10.0.0` veya üzeri seçin
5. **Add Package** butonuna tıklayın
6. Açılan pencerede **FirebaseStorage** paketini seçin ve **Add Package** butonuna tıklayın

> **Not:** Eğer Firebase SDK zaten ekliyse, sadece **FirebaseStorage** modülünü projeye eklemeniz yeterli.

## 🔒 2. Firebase Console'da Storage Kurallarını Güncelle

1. [Firebase Console](https://console.firebase.google.com/) adresine gidin
2. Projenizi seçin
3. Sol menüden **Storage** > **Rules** sekmesine gidin
4. Aşağıdaki kuralları yapıştırın:

```
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    
    // Profil resimleri - sadece kendi profil resmini yükleyebilir
    match /profile_images/{userId}_{filename} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
                      request.auth.uid == userId &&
                      request.resource.size < 5 * 1024 * 1024 && 
                      request.resource.contentType.matches('image/.*');
    }
    
    // Post resimleri - sadece kendi postlarına resim yükleyebilir
    match /post_images/{userId}/{filename} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
                      request.auth.uid == userId &&
                      request.resource.size < 10 * 1024 * 1024 && 
                      request.resource.contentType.matches('image/.*');
      allow delete: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

5. **Publish** butonuna tıklayın

## 🔥 3. Firebase Storage'ı Başlat

`bingoApp.swift` dosyasına FirebaseStorage import'u ekleyin:

```swift
import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseStorage  // ← Bu satırı ekleyin

@main
struct bingoApp: App {
    // ... geri kalan kod
}
```

## ✅ 4. Test Edin

1. Projeyi temizleyin: **Product > Clean Build Folder** (⇧⌘K)
2. Projeyi derleyin: **Product > Build** (⌘B)
3. Uygulamayı çalıştırın: **Product > Run** (⌘R)

### Test Senaryoları:

1. **Profil Fotoğrafı Yükleme:**
   - Profil sekmesine gidin
   - Sağ üst köşedeki düzenle butonuna tıklayın
   - "Profil Fotoğrafı Değiştir" butonuna tıklayın
   - Bir resim seçin ve kaydedin

2. **Post Resmi Yükleme:**
   - Ana sayfada "+" butonuna tıklayın
   - "Fotoğraf" veya "Kamera" butonlarından birini seçin
   - Resim ekleyip post paylaşın

## 🎯 Eklenen Yeni Özellikler

### ✅ Tamamlanan:
- ✅ `StorageService.swift` - Profesyonel resim yönetimi servisi
- ✅ Post'lara resim yükleme özelliği
- ✅ Profil fotoğrafı yükleme/güncelleme
- ✅ Firebase Storage güvenlik kuralları
- ✅ Resim optimizasyonu (JPEG compression)
- ✅ Yükleme progress göstergeleri
- ✅ Hata yönetimi

### 📁 Yeni Dosyalar:
- `bingo/Services/StorageService.swift` - Resim yönetim servisi

### 🔄 Güncellenen Dosyalar:
- `bingo/Services/SocialMediaService.swift` - Storage entegrasyonu
- `bingo/Views/CreatePostView.swift` - Resim yükleme aktif
- `bingo/Views/EditProfileView.swift` - Profil fotoğrafı yükleme
- `bingo/Views/MainTabView.swift` - Profil fotoğrafı gösterimi

## 🐛 Sorun Giderme

### "Module 'FirebaseStorage' not found" hatası:
1. Xcode'u kapatın
2. `~/Library/Developer/Xcode/DerivedData` klasörünü silin
3. Projeyi tekrar açın ve temiz bir build yapın

### Resim yüklenmiyor:
1. Firebase Console > Storage bölümünde kuralların doğru olduğunu kontrol edin
2. Internet bağlantınızı kontrol edin
3. Xcode console'da DEBUG loglarını kontrol edin

### Resimler gösterilmiyor:
1. Firebase Storage URL'lerinin doğru olduğunu kontrol edin
2. Firestore'da `profileImageURL` ve `imageURL` alanlarının dolu olduğunu kontrol edin

## 📱 Mimari Değişiklikler

Mevcut mimariye uygun olarak tasarlandı:

- **Service Pattern**: StorageService ayrı bir servis olarak eklendi
- **Singleton Pattern**: `StorageService.shared` ile tek instance
- **Result Type**: Hata yönetimi için Swift Result tipi kullanıldı
- **Async/Callback**: Firebase completion handlers ile uyumlu
- **Separation of Concerns**: Storage işlemleri ayrı serviste

## 🎨 Kullanıcı Deneyimi İyileştirmeleri

- ✅ Resim seçimi için PhotosPicker kullanımı
- ✅ Kamera erişimi için ImagePicker
- ✅ Yükleme sırasında loading göstergesi
- ✅ Optimistic UI updates
- ✅ Hata mesajları
- ✅ Resim önizleme

---

**Not:** Mevcut çalışan özellikler korunmuştur. Geriye dönük uyumluluk sağlanmıştır.

