//
//  CommunityThreadEnums.swift
//  CommunityDomain
//

import Foundation

/// 스레드 카테고리. rawValue 는 서버 enum 과 1:1.
public enum CommunityThreadCategory: String, CaseIterable, Sendable, Hashable {
    case study = "STUDY"
    case qna = "QNA"
    case project = "PROJECT"
    case free = "FREE"

    public var displayName: String {
        switch self {
        case .study: return "스터디"
        case .qna: return "질문"
        case .project: return "프로젝트"
        case .free: return "자유"
        }
    }

    /// 서버 `icon` 이 비었을 때 쓰는 폴백 이모지.
    public var defaultIcon: String {
        switch self {
        case .study: return "📚"
        case .qna: return "❓"
        case .project: return "🚀"
        case .free: return "💬"
        }
    }
}

public enum ThreadMemberRole: String, Sendable, Hashable {
    case owner = "OWNER"
    case admin = "ADMIN"
    case member = "MEMBER"

    /// 참여자 목록 배지 문구. 명세가 요구하는 구분은 개설자/참여자 둘뿐이다.
    ///
    /// `ADMIN` 은 개설자 위임 직후의 전 개설자 상태라(서버가 `OWNER` ↔ `ADMIN` 을 원자적으로
    /// 스왑한다) 권한상 일반 참여자와 같게 다룬다 — 나가기도 위임도 막지 않는다.
    public var displayName: String {
        switch self {
        case .owner: return "개설자"
        case .admin, .member: return "참여자"
        }
    }
}

public enum ThreadMessageType: String, Sendable, Hashable {
    case text = "TEXT"
    case image = "IMAGE"
    case system = "SYSTEM"
}

/// 리스트 필터. Figma `_필터메뉴` 항목과 서버 `filter` 파라미터가 1:1 로 대응한다.
public enum CommunityThreadFilter: Hashable, Sendable {
    case all
    case unread
    case category(CommunityThreadCategory)

    /// `GET /threads` 의 `filter` 쿼리 값.
    public var queryValue: String {
        switch self {
        case .all: return "all"
        case .unread: return "unread"
        case .category(let category): return category.rawValue
        }
    }

    public var displayName: String {
        switch self {
        case .all: return "전체"
        case .unread: return "안읽음"
        case .category(let category): return category.displayName
        }
    }

    /// 읽음 상태 축. 카테고리와 성격이 달라 메뉴에서 따로 묶는다.
    public static let statusItems: [CommunityThreadFilter] = [.all, .unread]

    /// 카테고리 축. 메뉴에서 구분선 아래 묶음이다.
    public static let categoryItems: [CommunityThreadFilter] =
        CommunityThreadCategory.allCases.map(CommunityThreadFilter.category)

    /// 메뉴 표시 순서. 구분선은 View 가 두 묶음 사이에 넣는다.
    public static let menuItems: [CommunityThreadFilter] = statusItems + categoryItems
}

/// 로컬 전송 상태. 서버 `status` 는 값이 `SENT` 하나뿐이라 정보가 없어 쓰지 않는다.
/// 삭제 여부는 `deletedAt` 이 표현한다.
public enum ThreadMessageDeliveryState: Sendable, Hashable {
    case sending
    case sent
    case failed
}
