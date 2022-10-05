//
//  DatabaseManager.swift
//  Messenger
//
//  Created by Muhammad Vicky on 20/09/22.
//

import Foundation
import FirebaseDatabase
import MessageKit
import CoreLocation

/// Manager object to read and write data to real time firebase database
final class DatabaseManager {
    
    /// Shared instance of class
    static let shared = DatabaseManager()
    
    private let database = Database.database().reference()
    
    private init(){}
    
    static func safeEmail(emailAddress : String) -> String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
}

extension DatabaseManager{
    
    /// Returns dictionary node at child path
    public func getDataFor(path: String, completion: @escaping (Result<Any, Error>) -> Void){
        database.child(path).observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
}

// MARK: - Account Management
extension DatabaseManager{
    
    /// Check if user exist for given email
    /// Parameters
    /// - `email`:              Target email to be checked
    /// - `completion`:   Async closure to return with result
    public func userExists(with email:String, completion : @escaping ((Bool)->Void)){
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        database.child(safeEmail).observeSingleEvent(of: .value, with: {
            snapshot in
            guard snapshot.exists() else{
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
        /*
         
         *users
         "safeEmail": "xaxaxa-gmail-com"[
            "first_name" : firstName,
            "last_name"  : lastName,
            "email"      : email,
            "user_friend": (email-friendEmail){
                [
                    "name"          : friendName,
                    "email"         : friendEmail(unique),
                    "conversations" : {
                            "messages" : {
                                    "id"        : messageId,
                                    "content"   : content,
                                    "date"      : date,
                                    "is_read"   : isRead,
                            }
                            "latest_messages":{
                                    "date"      : date,
                                    "is_read"   : isRead,
                                    "message"   : message
                            }
                    }
                ]
            }
         ]
         
         *all_users
         "safe_email" : "xaxaxa-gmail-com"[
            "name"       : name,
            "email"      : email(unique),
         ]
         
         */
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: user.emailAddress)
        database.child(safeEmail).setValue([
            "first_name" : user.firstName,
            "last_name" : user.lastName
        ], withCompletionBlock: { [weak self] error, _ in
            guard let strongSelf = self else{
                return
            }
            
            guard error == nil else {
                // if failed write to database
                print("failed to write to database")
                completion(false)
                return
            }
            
            var name = ""
            if user.lastName == nil {
                name = user.firstName
            } else {
                name = user.firstName + " " + user.lastName!
            }
            
            strongSelf.database.child("users").observeSingleEvent(of: .value, with: { snapshot in
                if var usersCollection = snapshot.value as? [[String : String]]{
                    //append to user dictionary
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
    
    /// Get all users in the database
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
}

// MARK: - Conversation Management

extension DatabaseManager{
    /// Create a new conversation with target user email and first message sent
    public func createNewConversation(with otherUserEmail: String, name : String, firstMessage: Message, completion: @escaping (Bool)->Void){
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String,
              let currentName = UserDefaults.standard.value(forKey: "name") as? String else{
            return
        }
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        
        let ref = database.child(safeEmail)
        
        ref.observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard let strongSelf = self else{
                return
            }
            guard var userNode = snapshot.value as? [String : Any] else{
                print("user not found")
                completion(false)
                return
            }
            
            var message = ""
            
            switch firstMessage.kind {
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            let conversationId = "conversation_\(firstMessage.messageId)"
            let newConversationData : [String: Any] = [
                "id": conversationId,
                "name": name,
                "other_user_email": otherUserEmail,
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false
                ]
            ]
            
            let recipient_newConversationData : [String: Any] = [
                "id": conversationId,
                "name": currentName,
                "other_user_email": safeEmail,
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false
                ]
            ]
            
            //update recipient conversation entry
            strongSelf.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: { [weak self] snapshot in
                guard let strongSelf = self else{
                    return
                }
                if var conversations = snapshot.value as? [[String : Any]]{
                    // append
                    conversations.append(recipient_newConversationData)
                    strongSelf.database.child("\(otherUserEmail)/conversations").setValue(conversations)
                } else{
                    // create
                    strongSelf.database.child("\(otherUserEmail)/conversations").setValue([recipient_newConversationData])
                }
            })
            
            // Update current user conversation entry
            if var conversations = userNode["conversations"] as? [[String: Any]] {
                // conversation array exist for current user
                // you should append
                conversations.append(newConversationData)
                ref.setValue(userNode, withCompletionBlock: { error, _ in
                    guard error == nil else{
                        print("conversation array exist for current user")
                        completion(false)
                        return
                    }
                    strongSelf.finishCreatingConversation(name: name, conversationID: conversationId, firstMessage: firstMessage, completion: completion)
                })
            } else {
                // conversation array doesn't exist
                //create it
                userNode["conversations"] = [
                    newConversationData
                ]
                ref.setValue(userNode, withCompletionBlock: { error, _ in
                    guard error == nil else{
                        print("conversation array doesn't exist")
                        completion(false)
                        return
                    }
                    strongSelf.finishCreatingConversation(name: name, conversationID: conversationId, firstMessage: firstMessage, completion: completion)
                })
            }
        })
    }
    
    ///
    private func finishCreatingConversation(name : String, conversationID: String, firstMessage: Message, completion: @escaping(Bool) -> Void){
        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dateFormatter.string(from: messageDate)
        
        var message = ""
        switch firstMessage.kind {
        case .text(let messageText):
            message = messageText
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else{
            print("email gada")
            completion(false)
            return
        }
        
        let currentUserEmail = DatabaseManager.safeEmail(emailAddress: email)
        
        let collectionMessage: [String : Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.messageKindString,
            "content": message,
            "date": dateString,
            "sender_email": currentUserEmail,
            "is_read": false,
            "name" : name
        ]
        let value : [String : Any] = [
            "messages": [
                collectionMessage
            ]
        ]
        
        database.child("\(conversationID)").setValue(value, withCompletionBlock: { error, _ in
            guard error == nil else{
                print("error conversation id")
                completion(false)
                return
            }
            completion(true)
        })
    }
    
    /// Fetches and returns all conversations for the user with passed in email
    public func getAllConversations(for email:String, completion: @escaping(Result<[Conversation], Error>) -> Void){
        database.child("\(email)/conversations").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else{
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            let conversations: [Conversation] = value.compactMap({ dictionary in
                guard let conversationId = dictionary["id"] as? String,
                      let name = dictionary["name"] as? String,
                      let otherUserEmail = dictionary["other_user_email"] as? String,
                      let latestMessage = dictionary["latest_message"] as? [String: Any],
                      let date = latestMessage["date"] as? String,
                      let message = latestMessage["message"] as? String,
                      let isRead = latestMessage["is_read"] as? Bool else{
                    return nil
                }
                
                let latestMessageObject = LatestMessage(date: date, text: message, isRead: isRead)
                return Conversation(id: conversationId, name: name, otherUserEmail: otherUserEmail, latestMessage: latestMessageObject)
            })
            completion(.success(conversations))
        })
    }
    
    /// Gets all messages for a given conversation
    public func getAllMessagesForConversation(with id: String, completion: @escaping(Result<[Message],Error>) -> Void){
        database.child("\(id)/messages").observe(.value, with: {snapshot in
            guard let value = snapshot.value as? [[String: Any]] else{
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            let messages: [Message] = value.compactMap({ dictionary in
                guard let name = dictionary["name"] as? String,
                      let isRead = dictionary["is_read"] as? Bool,
                      let content = dictionary["content"] as? String,
                      let messageId = dictionary["id"] as? String,
                      let senderEmail = dictionary["sender_email"] as? String,
                      let type = dictionary["type"] as? String,
                      let dateString = dictionary["date"] as? String,
                      let date = ChatViewController.dateFormatter.date(from: dateString) else{
                    return nil
                }
                var kind : MessageKind?
                if type == "photo"{
                    // photo
                    guard let imageUrl = URL(string: content),
                           let placeholder = UIImage(systemName: "plus") else{
                        return nil
                    }
                    let media = Media(url: imageUrl, image: nil, placeholderImage: placeholder, size: CGSize(width: 300, height: 300))
                    kind = .photo(media)
                } else if type == "video" {
                    // video
                    guard let videoUrl = URL(string: content),
                           let placeholder = UIImage(systemName: "plus") else{
                        return nil
                    }
                    let media = Media(url: videoUrl, image: nil, placeholderImage: placeholder, size: CGSize(width: 300, height: 300))
                    kind = .video(media)
                } else if type == "location"{
                    let locationComponents = content.components(separatedBy: ",")
                    guard let longitude = Double(locationComponents[0]),
                          let latitude = Double(locationComponents[1]) else{
                        return nil
                    }
                    let location = Location(location: CLLocation(latitude: latitude, longitude: longitude), size: CGSize(width: 300, height: 300))
                    
                    kind = .location(location)
                } else {
                    kind = .text(content)
                }
                
                guard let finalKind = kind else{
                    return nil
                }
                
                let sender = Sender(photoURL: "", senderId: senderEmail, displayName: name)
                
                return Message(sender: sender, messageId: messageId, sentDate: date, kind: finalKind)
            })
            completion(.success(messages))
        })
    }
    
    /// Sends a message with target conversation and message
    public func sendMessage(to conversationId:String, otherUserEmail: String, name : String, newMessage:Message, completion: @escaping (Bool) -> Void){
        // add new message to messages
        //update sender lastest message
        //update recipient latest message
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        
        let currentSafeEmail = DatabaseManager.safeEmail(emailAddress: email)
        print(currentSafeEmail)
        database.child("\(conversationId)/messages").observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard let strongSelf = self else{
                return
            }
            guard var currentMessages = snapshot.value as? [[String : Any]],
                  let email = UserDefaults.standard.value(forKey: "email") as? String else{
                print("failed to get currentMessages")
                completion(false)
                return
            }
            
            
            let messageDate = newMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            var message = ""
            switch newMessage.kind {
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(let mediaItem):
                if let targetUrlString = mediaItem.url?.absoluteString{
                    message = targetUrlString
                }
            case .video(let mediaItem):
                if let targetUrlString = mediaItem.url?.absoluteString{
                    message = targetUrlString
                }
            case .location(let locationData):
                let location = locationData.location
                message = "\(location.coordinate.longitude),\(location.coordinate.latitude)"
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            
            let newMessageEntry: [String : Any] = [
                "id": newMessage.messageId,
                "type": newMessage.kind.messageKindString,
                "content": message,
                "date": dateString,
                "sender_email": currentSafeEmail,
                "is_read": false,
                "name" : name
            ]
            currentMessages.append(newMessageEntry)
            strongSelf.database.child("\(conversationId)/messages").setValue(currentMessages, withCompletionBlock: { error, _ in
                guard error == nil else {
                    print("failed to add currentMessages to database")
                    completion(false)
                    return
                }
                
                strongSelf.database.child("\(currentSafeEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                    var databaseEntryConversations = [[String : Any]]()
                    let updatedValue : [String : Any] = [
                        "date": dateString,
                        "is_read": false,
                        "message": message
                    ]
                    
                    if var currentUserConversations = snapshot.value as? [[String : Any]] {
                        var targetConversation : [String:Any]?
                        var position = 0
                        
                        for var conversation in currentUserConversations {
                            if let currentId = conversation["id"] as? String, currentId == conversationId {
                                targetConversation = conversation
                                conversation["latest_message"] = updatedValue
                                break
                            }
                            position += 1
                        }
                        
                        if var targetConversation = targetConversation {
                            targetConversation["latest_message"] = updatedValue
                            currentUserConversations[position] = targetConversation
                            databaseEntryConversations = currentUserConversations
                        } else{
                            let newConversationData : [String: Any] = [
                                "id": conversationId,
                                "name": name,
                                "other_user_email": DatabaseManager.safeEmail(emailAddress: otherUserEmail),
                                "latest_message": updatedValue
                            ]
                            currentUserConversations.append(newConversationData)
                            databaseEntryConversations = currentUserConversations
                        }
                    } else{
                        let newConversationData : [String: Any] = [
                            "id": conversationId,
                            "name": name,
                            "other_user_email": DatabaseManager.safeEmail(emailAddress: otherUserEmail),
                            "latest_message": updatedValue
                        ]
                        databaseEntryConversations = [
                            newConversationData
                        ]
                    }
                    
                    
                    
                    strongSelf.database.child("\(currentSafeEmail)/conversations").setValue(databaseEntryConversations, withCompletionBlock: { error, _ in
                        guard error == nil else{
                            print("error set value to my email")
                            completion(false)
                            return
                        }
                        // update latest message for recipient user
                        
                        strongSelf.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                            var databaseEntryConversations = [[String : Any]]()
                            let updatedValue : [String : Any] = [
                                "date": dateString,
                                "is_read": false,
                                "message": message
                            ]
                            
                            guard let currentName = UserDefaults.standard.value(forKey: "name") as? String else{
                                return
                            }
                            
                            if var otherUserConversations = snapshot.value as? [[String : Any]] {
                                var targetConversation : [String:Any]?
                                var position = 0
                                
                                for var conversation in otherUserConversations {
                                    if let currentId = conversation["id"] as? String, currentId == conversationId {
                                        targetConversation = conversation
                                        conversation["latest_message"] = updatedValue
                                        break
                                    }
                                    position += 1
                                }
                                
                                if var targetConversation = targetConversation {
                                    targetConversation["latest_message"] = updatedValue
                                    otherUserConversations[position] = targetConversation
                                    databaseEntryConversations = otherUserConversations
                                } else{
                                    // failed to find in current collection
                                    
                                    let newConversationData : [String: Any] = [
                                        "id": conversationId,
                                        "name": currentName,
                                        "other_user_email": currentSafeEmail,
                                        "latest_message": updatedValue
                                    ]
                                    otherUserConversations.append(newConversationData)
                                    databaseEntryConversations = otherUserConversations
                                }
                                
                            } else{
                                // current collection doesn't exist
                                let newConversationData : [String: Any] = [
                                    "id": conversationId,
                                    "name": currentName,
                                    "other_user_email": currentSafeEmail,
                                    "latest_message": updatedValue
                                ]
                                databaseEntryConversations = [
                                    newConversationData
                                ]
                            }
                            
                            strongSelf.database.child("\(otherUserEmail)/conversations").setValue(databaseEntryConversations, withCompletionBlock: { error, _ in
                                guard error == nil else{
                                    completion(false)
                                    return
                                }
                                completion(true)
                            })
                        })
                    })
                })
            })
        })
    }
    
    /// Delete conversation with conversationId as parameters
    public func deleteConversation(conversationId: String, completion: @escaping (Bool)->Void){
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        
        // Get all conversations for current user
        // delete conversation in collection with target id
        // reset those conversation for the user in database
        let ref = database.child("\(safeEmail)/conversations")
        ref.observeSingleEvent(of: .value, with: { snapshot in
            if var conversations = snapshot.value as? [[String: Any]]{
                var positionToRemove = 0
                for conversation in conversations {
                    if let id = conversation["id"] as? String,
                       id == conversationId {
                        print("found conversation to delete")
                        break
                    }
                    positionToRemove += 1
                }
                
                conversations.remove(at: positionToRemove)
                ref.setValue(conversations, withCompletionBlock: {error, _ in
                    guard error == nil else{
                        print("failed to remove conversation from database")
                        completion(false)
                        return
                    }
                    print("delete conversation success")
                    completion(true)
                })
            }
        })
    }
    
    /// Check is conversation exist or not, if exist return true else false
    public func conversationExist(with targetRecipientEmail: String, completion: @escaping (Result<String, Error>) -> Void){
        let safeRecipientEmail = DatabaseManager.safeEmail(emailAddress: targetRecipientEmail)
        guard let senderEmail = UserDefaults.standard.value(forKey: "email") as? String else{
            return
        }
        let safeSenderEmail = DatabaseManager.safeEmail(emailAddress: senderEmail)
        
        database.child("\(safeRecipientEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
            guard let collection = snapshot.value as? [[String : Any]] else{
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            // iterate and find conversation with target sender
            if let conversation = collection.first(where:{
                guard let targetSenderEmail = $0["other_user_email"] as? String else{
                    return false
                }
                return safeSenderEmail == targetSenderEmail
            }){
                // get id
                guard let id = conversation["id"] as? String else{
                    completion(.failure(DatabaseError.failedToFetch))
                    return
                }
                completion(.success(id))
                return
            }
            completion(.failure(DatabaseError.failedToFetch))
            return
        })
    }
}
