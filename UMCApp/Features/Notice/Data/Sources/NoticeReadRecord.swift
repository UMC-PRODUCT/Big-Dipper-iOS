//
//  NoticeReadRecord.swift
//  NoticeData
//
//  Created by 이예지 on 5/30/26.
//

import Foundation
import SwiftData

/// 공지 읽음 상태 로컬 저장 모델 (SwiftData + CloudKit Sync)
///
/// 서버 목록 응답에 읽음 여부가 없을 때, 현재 사용자가 읽은 공지 ID를
/// 계정별로 보존하기 위해 사용합니다.
@Model
public final class NoticeReadRecord {

    // MARK: - Property

    /// 읽음 상태를 저장한 멤버 ID
    ///
    /// - Note: 레거시(v2.2.0)가 `memberId: Int`로 프로덕션 CloudKit 스키마에 배포해
    ///   `CD_memberId`가 Int64로 확정돼 있다. CloudKit·Core Data 모두 배포된 필드의
    ///   타입 변경을 허용하지 않으므로, `String` 통일(절대 규칙 #2)은 이름을 바꾼
    ///   새 필드(`CD_memberKey`)로 분리해 적용한다. 기존 Int 필드는 사용하지 않는다.
    public var memberKey: String = "0"

    /// 읽은 공지의 서버 식별자
    public var noticeId: String = ""

    /// 마지막 업데이트 시간
    public var updatedAt: Date = Date()

    // MARK: - Init

    public init(
        memberKey: String,
        noticeId: String,
        updatedAt: Date = Date()
    ) {
        self.memberKey = memberKey
        self.noticeId = noticeId
        self.updatedAt = updatedAt
    }
}
