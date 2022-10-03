//
//  ProfileViewModel.swift
//  Messenger
//
//  Created by Muhammad Vicky on 30/09/22.
//

import Foundation

struct ProfileViewModel{
    let viewModelType: ProfileViewModelType
    let title : String
    let handler: (()->Void)?
}

enum ProfileViewModelType{
    case info, logout
}
