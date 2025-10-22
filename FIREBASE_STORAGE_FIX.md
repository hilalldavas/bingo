# Firebase Storage Paketi Ekleme Talimatları

## 🚨 Sorun
Profil fotoğrafı değiştirme özelliği çalışmıyor çünkü Firebase Storage paketi projeye eklenmemiş.

## ✅ Çözüm

### Adım 1: Firebase Storage Paketini Ekle

1. **Xcode'da projeyi açın**
2. **File > Add Package Dependencies** menüsüne gidin
3. URL alanına şunu yazın:
   ```
   https://github.com/firebase/firebase-ios-sdk
   ```
4. **Add Package** butonuna tıklayın
5. Açılan pencerede **FirebaseStorage** paketini seçin
6. **Add Package** butonuna tıklayın

### Adım 2: Projeyi Temizle ve Derle

1. **Product > Clean Build Folder** (⇧⌘K)
2. **Product > Build** (⌘B)

### Adım 3: Firebase Console'da Storage Kurallarını Güncelle

1. [Firebase Console](https://console.firebase.google.com/) adresine gidin
2. Projenizi seçin
3. Sol menüden **Storage** > **Rules** sekmesine gidin
4. Aşağıdaki kuralları yapıştırın:

```
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    
    // Profil resimleri
    match /profile_images/{userId}_{filename} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
                      request.auth.uid == userId &&
                      request.resource.size < 5 * 1024 * 1024 && 
                      request.resource.contentType.matches('image/.*');
    }
    
    // Post resimleri
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

### Adım 4: Test Et

1. Uygulamayı çalıştırın
2. Profil sekmesine gidin
3. Sağ üst köşedeki düzenle butonuna tıklayın
4. "Profil Fotoğrafı Değiştir" butonuna tıklayın
5. Bir resim seçin

## 🔍 Debug İpuçları

Eğer hala çalışmıyorsa:

1. **Xcode Console'da hata mesajlarını kontrol edin**
2. **Firebase Console > Storage > Files** bölümünde dosyaların yüklenip yüklenmediğini kontrol edin
3. **Internet bağlantınızı kontrol edin**

## 📱 Beklenen Davranış

Paket eklendikten sonra:
- ✅ "Profil Fotoğrafı Değiştir" butonu çalışacak
- ✅ Fotoğraf seçici açılacak
- ✅ Resim yüklenecek ve profil fotoğrafı güncellenecek
- ✅ Post'lara da resim ekleyebileceksiniz

