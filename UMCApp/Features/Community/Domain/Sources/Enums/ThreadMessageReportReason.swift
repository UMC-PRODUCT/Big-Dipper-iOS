//
//  ThreadMessageReportReason.swift
//  CommunityDomain
//

import Foundation

/// 메시지 신고 사유. rawValue 는 서버 `ReportReason` enum 과 1:1.
///
/// 자유 서술 필드는 서버에 없다 — `etc` 를 골라도 함께 보낼 텍스트를 받을 곳이 없으므로
/// 시트에도 입력란을 두지 않는다.
public enum ThreadMessageReportReason: String, CaseIterable, Sendable, Hashable {
    case spam = "SPAM"
    case abuse = "ABUSE"
    case inappropriate = "INAPPROPRIATE"
    case privacy = "PRIVACY"
    case etc = "ETC"

    public var displayName: String {
        switch self {
        case .spam: return "스팸/광고"
        case .abuse: return "욕설/비방"
        case .inappropriate: return "부적절한 콘텐츠"
        case .privacy: return "개인정보 노출"
        case .etc: return "기타"
        }
    }
}
