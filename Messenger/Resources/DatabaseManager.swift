//
//  DatabaseManager.swift
//  Messenger
//
//  Created by Muhammad Vicky on 20/09/22.
//

import Foundation
import FirebaseDatabase
import MessageKit

final class DatabaseManager {
    
    static let shared = DatabaseManager()
    
    private let database = Database.database().reference()
    
    static func safeEmail(emailAddress : String) -> String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    
    
}

extension DatabaseManager{
    public func getDataFor(path: String, completion: @escaping (Result<Any, Error>) -> Void){
        self.database.child(path).observeSingleEvent(of: .value, with: { snapshot in
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
    
    public func userExists(with email:String, completion : @escaping ((Bool)->Void)){
        
        var safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        
        print(database.child(safeEmail))
        
        
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

// MARK: - Sending messages / conversations
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
                    strongSelf.database.child("\(otherUserEmail)/conversations").setValue(conversationId)
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
        
        database.child("\(conversationID)").setValue(value, withCompletionBlock: { [weak self] error, _ in
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
            print(snapshot.value as? [[String: Any]])
            
            guard let value = snapshot.value as? [[String: Any]] else{
                print("error here\(snapshot.value as? [[String: Any]])")
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
                break
            case .video(let mediaItem):
                if let targetUrlString = mediaItem.url?.absoluteString{
                    message = targetUrlString
                }
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
            
            let currentUserEmail = DatabaseManager.safeEmail(emailAddress: email)
            
            let newMessageEntry: [String : Any] = [
                "id": newMessage.messageId,
                "type": newMessage.kind.messageKindString,
                "content": message,
                "date": dateString,
                "sender_email": currentUserEmail,
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
                    guard var currentUserConversations = snapshot.value as? [[String : Any]] else{
                         completion(false)
                        return
                    }
                    
                    let updatedValue : [String : Any] = [
                        "date": dateString,
                        "is_read": false,
                        "message": message
                    ]
                    
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
                    targetConversation?["latest_message"] = updatedValue
                    guard let finalConversation = targetConversation else {
                        completion(false)
                        return
                    }
                    currentUserConversations[position] = finalConversation
                    strongSelf.database.child("\(currentSafeEmail)/conversations").setValue(currentUserConversations, withCompletionBlock: { error, _ in
                        guard error == nil else{
                            completion(false)
                            return
                        }
                        // update latest message for recipient user
                        
                        strongSelf.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                            guard var otherUserConversations = snapshot.value as? [[String : Any]] else{
                                 completion(false)
                                return
                            }
                            
                            let updatedValue : [String : Any] = [
                                "date": dateString,
                                "is_read": false,
                                "message": message
                            ]
                            
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
                            targetConversation?["latest_message"] = updatedValue
                            guard let finalConversation = targetConversation else {
                                completion(false)
                                return
                            }
                            otherUserConversations[position] = finalConversation
                            strongSelf.database.child("\(otherUserEmail)/conversations").setValue(otherUserConversations, withCompletionBlock: { error, _ in
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
}
