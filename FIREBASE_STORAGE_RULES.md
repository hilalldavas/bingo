# Firebase Storage Kuralları

Firebase Console'da Storage kurallarını güncellemek için:

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
      // Okuma: Giriş yapmış herkes okuyabilir
      allow read: if request.auth != null;
      
      // Yazma: Sadece kendi profil resmini yükleyebilir
      allow write: if request.auth != null && 
                      request.auth.uid == userId &&
                      request.resource.size < 5 * 1024 * 1024 && // Max 5MB
                      request.resource.contentType.matches('image/.*'); // Sadece resim dosyaları
    }
    
    // Post resimleri - sadece kendi postlarına resim yükleyebilir
    match /post_images/{userId}/{filename} {
      // Okuma: Giriş yapmış herkes okuyabilir
      allow read: if request.auth != null;
      
      // Yazma: Sadece kendi post klasörüne yazabilir
      allow write: if request.auth != null && 
                      request.auth.uid == userId &&
                      request.resource.size < 10 * 1024 * 1024 && // Max 10MB
                      request.resource.contentType.matches('image/.*'); // Sadece resim dosyaları
      
      // Silme: Sadece kendi postlarını silebilir
      allow delete: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

5. **Publish** butonuna tıklayın

## Test Adımları

Firebase Storage paketi eklendikten sonra:

1. **Xcode'da projeyi temizleyin:** Product > Clean Build Folder (⇧⌘K)
2. **Projeyi derleyin:** Product > Build (⌘B)
3. **Uygulamayı çalıştırın:** Product > Run (⌘R)
4. **Profil fotoğrafı değiştirmeyi test edin:**
   - Profil sekmesine gidin
   - Sağ üst köşedeki düzenle butonuna tıklayın
   - "Profil Fotoğrafı Değiştir" butonuna tıklayın
   - Bir resim seçin ve kaydedin

## Beklenen Sonuç

✅ Profil fotoğrafı başarıyla yüklenecek
✅ Hata mesajı kaybolacak
✅ Resim profil sayfasında görünecek
✅ Post'lara da resim ekleyebileceksiniz
