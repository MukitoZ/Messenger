//
//  Conversation.swift
//  Messenger
//
//  Created by Muhammad Vicky on 26/09/22.
//

import Foundation
import MessageKit

struct Conversation{
    let id: String
    let name : String
    let otherUserEmail : String
    let latestMessage : LatestMessage
}

struct LatestMessage{
    let date: String
    let text: String
    let isRead : Bool
}
