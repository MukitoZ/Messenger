//
//  DatabaseManager.swift
//  Messenger
//
//  Created by Muhammad Vicky on 20/09/22.
//

import Foundation
import FirebaseDatabase

final class DatabaseManager {
    
    static let shared = DatabaseManager()
    
    private let database = Database.database().reference()
    
    static func safeEmail(emailAddress : String) -> String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    
    
}

// MARK: -Account Management
extension DatabaseManager{
    
    public func userExists(with email:String, completion : @escaping ((Bool)->Void)){
        
        var safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        
        print(database.child(safeEmail))
        
        database.child(safeEmail).observeSingleEvent(of: .value, with: {
            snapshot in
            guard snapshot.value as? String != nil else{
                // if user doesn't exist
                completion(false)
                return
            }
            // if user exist
            completion(true)
        })
    }
    
    /// Insert new user to database
    public func insertUser(with user: ChatAppUser, completion : @escaping (Bool)->Void){
        database.child(user.safeEmail).setValue([
            "first_name" : user.firstName,
            "last_name" : user.lastName
        ], withCompletionBlock: {
            [weak self] error, _ in
            
            guard let strongSelf = self else{
                return
            }
            
            guard error == nil else {
                // if failed write to database
                print("failed to write to database")
                completion(false)
                return
            }
            
            strongSelf.database.child("users").observeSingleEvent(of: .value, with: { snapshot in
                if var usersCollection = snapshot.value as? [[String : String]]{
                    //append to user dictionary
                    var name = ""
                    if user.lastName == nil {
                        name = user.firstName
                    } else {
                        name = user.firstName + " " + user.lastName!
                    }
                    let newElement = [
                        "name": name,
                        "email": user.safeEmail
                    ]
                    usersCollection.append(newElement)
                    
                    strongSelf.database.child("users").setValue(usersCollection, withCompletionBlock: {
                        error, _ in
                        guard error == nil else{
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                } else{
                    //create that array
                    var name = ""
                    if user.lastName == nil {
                        name = user.firstName
                    } else {
                        name = user.firstName + " " + user.lastName!
                    }
                    let newCollection: [[String : String]] = [
                        [
                            "name": name,
                            "email": user.safeEmail
                        ]
                    ]
                    strongSelf.database.child("users").setValue(newCollection, withCompletionBlock: {
                        error, _ in
                        guard error == nil else{
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                }
            })
        })
    }
    public func getAllUsers(completion : @escaping (Result<[[String:String]], Error>)->Void){
        database.child("users").observeSingleEvent(of: .value, with: {
            snapshot in
            guard let value = snapshot.value as? [[String:String]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
    
    public enum DatabaseError: Error{
        case failedToFetch
    }
}

struct ChatAppUser{
    let firstName : String
    let lastName : String?
    let emailAddress : String
    
    var safeEmail : String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    
    var profilePictureFileName:String {
        return "\(safeEmail)_profile_picture.png"
    }
}
