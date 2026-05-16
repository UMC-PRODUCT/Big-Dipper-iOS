//
//  NoticeImagesRequestDTO.swift
//  NoticeData
//
//  Created by 이예지 on 5/17/26.
//

import Foundation
import NoticeDomain

/// 공지 이미지 추가/수정 요청 DTO
///
/// - `POST /api/v1/notices/{noticeId}/images`
/// - `PATCH /api/v1/notices/{noticeId}/images`
public struct NoticeImagesRequestDTO: Encodable {
    /// 첨부 이미지 ID 목록
    public let imageIds: [String]
}
