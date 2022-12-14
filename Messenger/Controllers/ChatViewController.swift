//
//  ChatViewController.swift
//  Messenger
//
//  Created by Muhammad Vicky on 22/09/22.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import AVKit
import CoreLocation

final class ChatViewController: MessagesViewController {
    
    private var senderPhotoURL : URL?
    private var otherUserPhotoURL: URL?
    
    public static let dateFormatter : DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        formatter.locale = .current
        return formatter
    }()
    
    public var isNewConversation = false
    public let otherUserEmail : String
    public var conversationId : String?
    
    private var messages = [Message]()
    
    private var selfSender : Sender?{
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else{
            return nil
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        return Sender(photoURL: "", senderId: safeEmail, displayName: "Me")
    }
    
    init(with email: String, id:String?){
        self.otherUserEmail = email
        self.conversationId = id
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .blue
        
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        messageInputBar.delegate = self
        setupInputButton()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
        if let conversationId = conversationId {
            listenForMessages(id: conversationId, shouldScrollToBottom: true)
        }
    }
    
    private func setupInputButton(){
        let button = InputBarButtonItem()
        button.setSize(CGSize(width: 35, height: 35), animated: false)
        button.setImage(UIImage(systemName: "paperclip"), for: .normal)
        button.onTouchUpInside { [weak self] _ in
            guard let strongSelf = self else{
                return
            }
            strongSelf.presentInputActionSheet()
        }
        messageInputBar.setLeftStackViewWidthConstant(to: 36, animated: false)
        messageInputBar.setStackViewItems([button], forStack: .left, animated: false)
    }
    
    private func presentInputActionSheet(){
        let actionSheet = UIAlertController(title: "Attach Media", message: "What would you like to attach?", preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Photo", style: .default, handler: {[weak self] _ in
            self?.presentPhotoInputActionSheet()
        }))
        actionSheet.addAction(UIAlertAction(title: "Video", style: .default, handler: { [weak self] _ in
            self?.presentVideoInputActionSheet()
        }))
        actionSheet.addAction(UIAlertAction(title: "Audio", style: .default, handler: { _ in
            
        }))
        actionSheet.addAction(UIAlertAction(title: "Location", style: .default, handler: {[weak self] _ in
            self?.presentLocationPicker()
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(actionSheet, animated: true)
    }
    
    private func presentLocationPicker(){
        let vc = LocationPickerViewController(coordinates: nil)
        vc.title = "Pick a Location"
        vc.navigationItem.largeTitleDisplayMode = .never
        vc.completion = {
            [weak self] selectedCoordinate in
            guard let strongSelf = self else{
                return
            }
            guard let messageId = strongSelf.createMessageId(),
                  let conversationId = strongSelf.conversationId,
                  let name = strongSelf.title,
                  let selfSender = strongSelf.selfSender else{
                return
            }
            
            let longitude : Double = selectedCoordinate.longitude
            let latitude : Double = selectedCoordinate.latitude
            
            print("Longitude : \(longitude), Latitude: \(latitude)")
            
            
            let location = Location(location: CLLocation(latitude: latitude, longitude: longitude), size: .zero)
            let message = Message(sender: selfSender, messageId: messageId, sentDate: Date(), kind: .location(location))
            
            DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: strongSelf.otherUserEmail, name: name, newMessage: message, completion: { success in
                if success {
                    print("sent location message")
                } else{
                    print("failed send location message")
                }
            })
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func presentPhotoInputActionSheet(){
        let actionSheet = UIAlertController(title: "Attach Photo", message: "Where would you like to attach a photo from?", preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: {[weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(actionSheet, animated: true)
    }
    
    private func presentVideoInputActionSheet(){
        let actionSheet = UIAlertController(title: "Attach Video", message: "Where would you like to attach a video from?", preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: {[weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Library", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(actionSheet, animated: true)
    }

        
    private func listenForMessages(id: String, shouldScrollToBottom : Bool){
        DatabaseManager.shared.getAllMessagesForConversation(with: id, completion: {[weak self]result in
            guard let strongSelf = self else{
                return
            }
            switch result{
            case .success(let messages):
                guard !messages.isEmpty else{
                    return
                }
                strongSelf.messages = messages
                DispatchQueue.main.async {
                    strongSelf.messagesCollectionView.reloadDataAndKeepOffset()
                    if shouldScrollToBottom{
                        strongSelf.messagesCollectionView.scrollToLastItem()
                    }
                }
            case .failure(let error):
                print("failed to get messages : \(error)")
            }
        })
    }
    
}

extension ChatViewController : InputBarAccessoryViewDelegate{
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty, let selfSender = self.selfSender, let messageId = createMessageId() else{
            return
        }
        
        print("Sending :\(text)")
        
        let message = Message(sender: selfSender, messageId: messageId, sentDate: Date(), kind: .text(text))
        
        // Send message
        if isNewConversation{
            // Create new conversation in database
            DatabaseManager.shared.createNewConversation(with: otherUserEmail, name: title ?? "User", firstMessage: message, completion: {[weak self] success in
                guard let strongSelf = self else{
                    return
                }
                if success {
                    strongSelf.isNewConversation = false
                    print("message sent")
                    let newConversationId = "conversation_\(message.messageId)"
                    strongSelf.conversationId = newConversationId
                    strongSelf.listenForMessages(id: newConversationId, shouldScrollToBottom: true)
                } else{
                    print("failed to send a message")
                }
            })
        } else{
            // Append to existing conversation data
            guard let conversationId = conversationId, let name = title
            else{
                return
            }
            DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: otherUserEmail, name: name, newMessage: message, completion: { success in
                if success {
                    print("message sent")
                } else{
                    print("message failed to send")
                }
            })
        }
        inputBar.inputTextView.text.removeAll()
    }
    
    private func createMessageId() -> String? {
        // date, otherUserEmail, senderEmail, randomInt
        let dateString = Self.dateFormatter.string(from: Date())
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else{
            return nil
        }
        
        let safeCurrentUserEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
        
        let newIdentifier = "\(otherUserEmail)_\(safeCurrentUserEmail)_\(dateString)"
        
        print("created messageId: \(newIdentifier)")
        
        return newIdentifier
    }
}

extension ChatViewController : UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        guard let messageId = createMessageId(),
              let conversationId = conversationId,
              let name = self.title,
              let selfSender = selfSender else{
            return
        }
        
        if let image = info[UIImagePickerController.InfoKey.editedImage] as? UIImage,
           let imageData = image.pngData() {
            // Upload Image
            let fileName = "photo_message_" + messageId.replacingOccurrences(of: " ", with: "-") + ".png"
            StorageManager.shared.uploadMessagePhoto(with: imageData, fileName: fileName, completion: { [weak self] result in
                guard let strongSelf = self else{
                    return
                }
                
                switch result {
                case .success(let urlString):
                    //ready to send message
                    print("uploaded message photo : \(urlString)")
                    guard let url = URL(string: urlString),
                          let placeholder = UIImage(systemName: "plus") else{
                        return
                    }
                    
                    let media = Media(url: url, image: nil, placeholderImage: placeholder, size: .zero)
                    let message = Message(sender: selfSender, messageId: messageId, sentDate: Date(), kind: .photo(media))
                    
                    DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: strongSelf.otherUserEmail, name: name, newMessage: message, completion: { success in
                        if success {
                            print("sent photo message")
                        } else{
                            print("failed send photo message")
                        }
                    })
                case .failure(let error):
                    print("message photo upload error : \(error)")
                }
            })
        } else if let videoUrl = info[.mediaURL] as? URL {
            // Upload Video
            let fileName = "video_message_" + messageId.replacingOccurrences(of: " ", with: "-") + ".mov"
            StorageManager.shared.uploadMessageVideo(with: videoUrl, fileName: fileName, completion: { [weak self] result in
                guard let strongSelf = self else{
                    return
                }
                
                switch result {
                case .success(let urlString):
                    //ready to send message
                    print("uploaded message video : \(urlString)")
                    guard let url = URL(string: urlString),
                          let placeholder = UIImage(systemName: "plus") else{
                        return
                    }
                    
                    let media = Media(url: url, image: nil, placeholderImage: placeholder, size: .zero)
                    let message = Message(sender: selfSender, messageId: messageId, sentDate: Date(), kind: .video(media))
                    
                    DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: strongSelf.otherUserEmail, name: name, newMessage: message, completion: { success in
                        if success {
                            print("sent video message")
                        } else{
                            print("failed send video message")
                        }
                    })
                case .failure(let error):
                    print("message video upload error : \(error)")
                }
            })
        }
        
        
    }
}

extension ChatViewController : MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate{
    func currentSender() -> MessageKit.SenderType {
        if let sender = selfSender{
            return sender
        }
        fatalError("self sender is nil, email should be cached")
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessageKit.MessagesCollectionView) -> MessageKit.MessageType {
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessageKit.MessagesCollectionView) -> Int {
        return messages.count
    }
    
    func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        guard let message = message as? Message else{
            return
        }
        switch message.kind{
        case .photo(let media):
            guard let imageUrl = media.url else{
                return
            }
            imageView.sd_setImage(with: imageUrl)
        default:
            break
        }
    }
    
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        let sender = message.sender
        if sender.senderId == selfSender?.senderId {
            // the message that sender sent
            return .link
        }
        return .secondarySystemBackground
    }
    
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        let sender = message.sender
        if sender.senderId == selfSender?.senderId {
            // show sender image
            if let currentUserImageURL = self.senderPhotoURL{
                avatarView.sd_setImage(with: currentUserImageURL)
            } else{
                // images/safeemail_profile_picture.png
                guard let email = UserDefaults.standard.value(forKey: "email") as? String else{
                    return
                }
                
                let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
                let path = "images/\(safeEmail)_profile_picture.png"
                
                // fetch image url
                StorageManager.shared.downloadURL(for: path, completion: { [weak self] result in
                    switch result {
                    case .success(let url):
                        self?.senderPhotoURL = url
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: url)
                        }
                    case .failure(let error):
                        print("failed download avatar user image : \(error)")
                    }
                })
            }
        } else{
            // show other user image
            if let otherUserImageURL = self.otherUserPhotoURL{
                avatarView.sd_setImage(with: otherUserImageURL)
            } else{
                // images/safeemail_profile_picture.png
                let email = self.otherUserEmail
                
                let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
                let path = "images/\(safeEmail)_profile_picture.png"
                
                // fetch image url
                StorageManager.shared.downloadURL(for: path, completion: { [weak self] result in
                    switch result {
                    case .success(let url):
                        self?.otherUserPhotoURL = url
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: url)
                        }
                    case .failure(let error):
                        print("failed download avatar user image : \(error)")
                    }
                })
            }
        }
    }
    
}

extension ChatViewController : MessageCellDelegate{
    
    func didTapMessage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else{
            return
        }
        
        let message = messages[indexPath.section]
        switch message.kind{
        case .location(let locationData):
            let coordinates = locationData.location.coordinate
            let vc = LocationPickerViewController(coordinates: coordinates)
            vc.title = "Location"
            self.navigationController?.pushViewController(vc, animated: true)
        default:
            break
        }
    }
    
    func didTapImage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else{
            return
        }
        
        let message = messages[indexPath.section]
        switch message.kind{
        case .photo(let media):
            guard let imageUrl = media.url else{
                return
            }
            let vc = PhotoViewerViewController(with: imageUrl)
            self.navigationController?.pushViewController(vc, animated: true)
        case .video(let media):
            guard let videoUrl = media.url else{
                return
            }
            let vc = AVPlayerViewController()
            vc.player = AVPlayer(url: videoUrl)
            present(vc, animated: true)
        default:
            break
        }
    }
}
