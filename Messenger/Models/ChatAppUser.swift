//
//  ChatAppUser.swift
//  Messenger
//
//  Created by Muhammad Vicky on 26/09/22.
//

import Foundation

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
