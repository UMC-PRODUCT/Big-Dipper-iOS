//
//  ReportMessageBody.swift
//  CommunityData
//

import Foundation

/// `POST /api/v1/community/messages/{messageId}/report` 본문.
///
/// 서버가 `reason` 을 `@NotNull` 로 받고 자유 서술 필드는 두지 않았다 — 사유 코드 하나가 전부다.
public struct ReportMessageBody: Encodable {

    // MARK: - Property

    /// ``CommunityDomain/ThreadMessageReportReason`` 의 rawValue.
    public let reason: String

    // MARK: - Init

    public init(reason: String) {
        self.reason = reason
    }
}
