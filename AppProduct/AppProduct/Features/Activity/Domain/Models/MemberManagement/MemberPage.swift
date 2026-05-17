//
//  MemberPage.swift
//  AppProduct
//
//  Created by JEONG on 5/17/26.
//

import Foundation

struct MemberPage: Equatable {
    let members: [MemberManagementItem]
    let hasNext: Bool
    let currentPage: Int
}
