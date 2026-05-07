//
//  NoticeImagesRequestDTO.swift
//  AppProduct
//
//  Created by JEONG on 5/7/26.
//

import Foundation

/// 공지 이미지 추가/수정 요청 DTO
///
/// - `POST /api/v1/notices/{noticeId}/images`
/// - `PATCH /api/v1/notices/{noticeId}/images`
struct NoticeImagesRequestDTO: Encodable {
    /// 첨부 이미지 ID 목록
    let imageIds: [String]
}
