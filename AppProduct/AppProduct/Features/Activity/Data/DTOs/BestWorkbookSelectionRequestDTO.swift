//
//  BestWorkbookSelectionRequestDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 2/18/26.
//

import Foundation

/// 베스트 워크북 선정 요청 DTO
///
/// `PATCH /api/v2/curriculums/challenger-workbooks/weekly-best/{weeklyBestWorkbookId}`
struct BestWorkbookSelectionRequestDTO: Codable, Sendable, Equatable {
    let bestReason: String
}
