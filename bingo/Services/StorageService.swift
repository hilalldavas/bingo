import Foundation
import FirebaseStorage
import UIKit

/// Firebase Storage ile resim yükleme/indirme işlemlerini yöneten servis
class StorageService {
    static let shared = StorageService()
    private let storage = Storage.storage()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Profil fotoğrafı yükler
    /// - Parameters:
    ///   - image: Yüklenecek UIImage
    ///   - userId: Kullanıcı ID'si
    ///   - completion: Başarılı olursa resim URL'si, hata olursa Error döner
    func uploadProfileImage(_ image: UIImage, userId: String, completion: @escaping (Result<String, Error>) -> Void) {
        print("DEBUG: uploadProfileImage - Başlatıldı, userId: \(userId)")
        
        // Geçici olarak mock URL döndür - test için
        let mockURL = "https://ui-avatars.com/api/?name=\(userId)&background=random&color=fff&size=200"
        print("DEBUG: uploadProfileImage - Mock URL döndürülüyor: \(mockURL)")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(.success(mockURL))
        }
    }
    
    /// Post resmi yükler
    /// - Parameters:
    ///   - image: Yüklenecek UIImage
    ///   - postId: Post ID'si
    ///   - userId: Kullanıcı ID'si
    ///   - completion: Başarılı olursa resim URL'si, hata olursa Error döner
    func uploadPostImage(_ image: UIImage, postId: String, userId: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(StorageError.imageCompressionFailed))
            return
        }
        
        let filename = "\(postId)_\(Date().timeIntervalSince1970).jpg"
        let storageRef = storage.reference().child("post_images/\(userId)/\(filename)")
        
        uploadImage(data: imageData, to: storageRef, completion: completion)
    }
    
    /// Resim siler
    /// - Parameters:
    ///   - imageURL: Silinecek resmin URL'si
    ///   - completion: İşlem sonucu
    func deleteImage(at imageURL: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Firebase Storage URL'sinden referans oluştur
        storage.reference(forURL: imageURL).delete { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Genel resim yükleme fonksiyonu
    private func uploadImage(data: Data, to storageRef: StorageReference, completion: @escaping (Result<String, Error>) -> Void) {
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        print("DEBUG: StorageService - Resim yükleniyor: \(storageRef.fullPath)")
        
        storageRef.putData(data, metadata: metadata) { metadata, error in
            if let error = error {
                print("DEBUG: StorageService - Yükleme hatası: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            // Başarılı yükleme - Download URL al
            storageRef.downloadURL { url, error in
                if let error = error {
                    print("DEBUG: StorageService - URL alma hatası: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let downloadURL = url?.absoluteString else {
                    print("DEBUG: StorageService - URL oluşturulamadı")
                    completion(.failure(StorageError.urlGenerationFailed))
                    return
                }
                
                print("DEBUG: StorageService - Yükleme başarılı: \(downloadURL)")
                completion(.success(downloadURL))
            }
        }
    }
}

// MARK: - Custom Errors

enum StorageError: LocalizedError {
    case imageCompressionFailed
    case urlGenerationFailed
    case invalidImageData
    
    var errorDescription: String? {
        switch self {
        case .imageCompressionFailed:
            return "Resim sıkıştırılamadı"
        case .urlGenerationFailed:
            return "Resim URL'si oluşturulamadı"
        case .invalidImageData:
            return "Geçersiz resim verisi"
        }
    }
}