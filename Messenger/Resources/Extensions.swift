//
//  Extensions.swift
//  Messenger
//
//  Created by Muhammad Vicky on 19/09/22.
//

import Foundation
import UIKit

extension UIView{
    
    public var width : CGFloat{
        return frame.size.width
    }
    
    public var heigth : CGFloat{
        return frame.size.height
    }
    
    public var top : CGFloat{
        return frame.origin.y
    }
    
    public var bottom : CGFloat{
        return frame.size.height + frame.origin.y
    }
    
    public var left : CGFloat{
        return frame.origin.x
    }
    
    public var right : CGFloat{
        return frame.size.width + frame.origin.x
    }
}

extension Notification.Name {
    /// Notification when user log in
    static let didLoginNotification = Notification.Name("didLoginNotification")
}
