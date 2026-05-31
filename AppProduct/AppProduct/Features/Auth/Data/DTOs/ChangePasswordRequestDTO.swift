//
//  ChangePasswordRequestDTO.swift
//  AppProduct
//

import Foundation

struct ChangePasswordRequestDTO: Encodable {
    let currentPassword: String
    let newPassword: String
}
