//
//  StorageManager.swift
//  Messenger
//
//  Created by Muhammad Vicky on 22/09/22.
//

import Foundation
import FirebaseStorage

/// Allows you to get, fetch, and upload files to firebase storage
final class StorageManager {
    static let shared = StorageManager()
    
    private let storage = Storage.storage().reference()
    
    private init(){}
    
    public typealias UploadFileCompletion = ((Result<String, Error>)-> Void)
    
    ///Upload picture to database storage and returns completion with url string to download
    public func uploadProfilePicture(with data : Data, fileName : String, completion: @escaping UploadFileCompletion){
        storage.child("images/\(fileName)").putData(data, metadata: nil, completion: {
            [weak self]metadata, error in
            guard error==nil else{
                print("failed to upload")
                completion(.failure(StorageError.failedToUpload))
                return
            }
            
            self?.storage.child("images/\(fileName)").downloadURL(completion: {
                url, error in
                guard let url = url else{
                    print("failed to get download url")
                    completion(.failure(StorageError.failedToGetDownloadURL))
                    return
                }
                let urlString = url.absoluteString
                print("download url returned : \(urlString)")
                completion(.success(urlString))
            })
        })
        
    }
    
    /// Upload image that will be sent in a conversation message
    public func uploadMessagePhoto(with data : Data, fileName : String, completion: @escaping UploadFileCompletion){
        storage.child("message_images/\(fileName)").putData(data, metadata: nil, completion: {
            [weak self] metadata, error in
            guard error==nil else{
                print("failed to upload image")
                completion(.failure(StorageError.failedToUpload))
                return
            }
            
            self?.storage.child("message_images/\(fileName)").downloadURL(completion: {
                url, error in
                guard let url = url else{
                    print("failed to get download url")
                    completion(.failure(StorageError.failedToGetDownloadURL))
                    return
                }
                let urlString = url.absoluteString
                print("download url returned : \(urlString)")
                completion(.success(urlString))
            })
        })
    }
    
    /// Upload video that will be sent in a conversation message
    public func uploadMessageVideo(with fileUrl : URL, fileName : String, completion: @escaping UploadFileCompletion){
        storage.child("message_videos/\(fileName)").putFile(from: fileUrl, metadata: nil, completion: {
            [weak self] metadata, error in
            guard error==nil else{
                print("failed to upload video file")
                completion(.failure(StorageError.failedToUpload))
                return
            }
            
            self?.storage.child("message_videos/\(fileName)").downloadURL(completion: {
                url, error in
                guard let url = url else{
                    print("failed to get download url")
                    completion(.failure(StorageError.failedToGetDownloadURL))
                    return
                }
                let urlString = url.absoluteString
                print("download url returned : \(urlString)")
                completion(.success(urlString))
            })
        })
    }
    
    public func downloadURL(for path: String, completion: @escaping (Result<URL, Error>) -> Void){
        let reference = storage.child(path)
        reference.downloadURL(completion: { url, error in
            guard let url = url, error == nil else{
                completion(.failure(StorageError.failedToGetDownloadURL))
                return
            }
            completion(.success(url))
        })
    }
}
