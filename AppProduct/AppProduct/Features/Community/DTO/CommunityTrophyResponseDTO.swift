//
//  CommunityTrophyResponseDTO.swift
//  AppProduct
//
//  Created by 김미주 on 2/14/26.
//

import Foundation

// MARK: - Trophy List

/// 상장 목록 조회 응답 DTO
/// `GET /api/v1/trophies`
struct TrophyListResponse: Codable {
    let trophyId: String
    let challengerId: String
    let week: String
    let challengerName: String
    let challengerProfileImage: String?
    let school: String?
    let part: String
    let title: String
    let content: String
    let url: String
}

extension TrophyListResponse {
    func toFameItem() -> CommunityFameItemModel {
        CommunityFameItemModel(
            week: Int(week) ?? 0,
            university: school ?? "알 수 없음",
            profileImage: challengerProfileImage,
            userName: challengerName,
            part: UMCPartType(apiValue: part) ?? .pm,
            workbookTitle: title,
            content: content,
            url: url
        )
    }
}
