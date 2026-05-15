//
//  NoticePatchRequestDTO.swift
//  AppProduct
//
//  Created by 이예지 on 2/12/26.
//

import Foundation

/// 공지사항 수정 요청 DTO
struct UpdateNoticeRequestDTO: Encodable {
    let title: String
    let content: String
    /// 필독 공지 여부
    let mustRead: Bool
}

