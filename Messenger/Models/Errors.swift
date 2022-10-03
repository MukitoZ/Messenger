//
//  Error.swift
//  Messenger
//
//  Created by Muhammad Vicky on 03/10/22.
//

import Foundation

public enum DatabaseError: Error {
    case failedToFetch
    
    public var localizedDescription: String{
        switch self {
        case .failedToFetch:
            return "Failed to fetch the database"
        }
    }
}

public enum StorageError: Error{
    case failedToUpload
    case failedToGetDownloadURL
    
    public var localizedDescription: String {
        switch self{
        case .failedToGetDownloadURL:
            return "Failed to get download url from database"
        case .failedToUpload:
            return "Failed to upload to database"
        }
    }
}
