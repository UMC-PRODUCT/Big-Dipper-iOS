//
//  NoticeType.swift
//  AppProduct
//
//  Created by 이예지 on 1/10/26.
//

import Foundation
import SwiftUI


// MARK: - NoticeType
/// NoticeChip에 쓰이는 enum
enum NoticeType: String, Equatable {
    case core = "중앙"
    case branch = "지부"
    case campus = "교내"
    case part = "파트"

    var textColor: Color { .white }

    var backgroundColor: Color { .indigo500 }
}
