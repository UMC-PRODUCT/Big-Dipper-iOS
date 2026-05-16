//
//  NoticePatchRequestDTO.swift
//  NoticeData
//
//  Created by 이예지 on 5/17/26.
//

import Foundation
import NoticeDomain

/// 공지사항 수정 요청 DTO
public struct UpdateNoticeRequestDTO: Encodable {
    public let title: String
    public let content: String
}
