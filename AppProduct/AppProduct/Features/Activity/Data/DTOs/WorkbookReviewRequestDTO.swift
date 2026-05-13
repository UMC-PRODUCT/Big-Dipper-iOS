//
//  WorkbookReviewRequestDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 2/18/26.
//

import Foundation

/// 챌린저 워크북 검토 요청 DTO
///
/// `POST /api/v2/curriculums/challenger-workbooks/missions/feedback`
struct WorkbookReviewRequestDTO: Codable, Sendable, Equatable {
    let challengerWorkbookId: Int
    let status: String
    let feedback: String
}
