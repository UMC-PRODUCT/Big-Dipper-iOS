//
//  MemberPage.swift
//  AppProduct
//
//  Created by euijjang97 on 5/17/26.
//

import Foundation

struct MemberPage: Equatable {
    let members: [MemberManagementItem]
    let hasNext: Bool
    let currentPage: Int
}
