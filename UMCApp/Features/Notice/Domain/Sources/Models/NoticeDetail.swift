//
//  NoticeDetail.swift
//  NoticeDomain
//
//  Created by 이예지 on 5/8/26.
//

import Foundation
import UMCFoundation

// MARK: - NoticeDetail

/// 공지사항 상세정보 엔티티
public struct NoticeDetail: Equatable, Identifiable, Hashable {
    /// 공지 고유 ID
    public let id: String
    /// 기수
    public let generation: String
    /// 공지 범위 (중앙/지부/교내)
    public let scope: NoticeScope
    /// 공지 카테고리
    public let category: NoticeCategory

    /// 필독 여부
    public let isMustRead: Bool

    /// 공지 제목
    public let title: String
    /// 공지 본문
    public let content: String

    /// 작성자 ID
    public let authorID: String
    /// 작성자 멤버 ID (authorMemberId)
    public let authorMemberId: String?
    /// 작성자 닉네임
    public let authorNickname: String?
    /// 작성자 이름
    public let authorName: String
    /// 작성자 프로필 이미지 URL
    public let authorImageURL: String?

    /// 생성일
    public let createdAt: Date
    /// 수정일
    public let updatedAt: Date?

    /// 수신 대상
    public let targetAudience: TargetAudience

    /// 수정/삭제 권한 보유 여부
    public let hasPermission: Bool

    /// 첨부 이미지 URL 목록
    public let images: [String]
    /// 첨부 이미지 원본 메타데이터 (수정 화면의 교체 API 구성에 사용)
    public var imageItems: [NoticeAttachmentImage] = []
    /// 첨부 링크 목록
    public let links: [String]
    /// 첨부 투표
    public let vote: NoticeVote?

    /// 작성자 표기 기본값 (닉네임/이름-xxth)
    public var defaultAuthorDisplayName: String {
        let trimmedNickname = authorNickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedName = authorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let generationText = generationOrdinalText

        if trimmedName.isEmpty || trimmedName == "알 수 없음" {
            return "알 수 없음"
        }

        if !trimmedNickname.isEmpty && !trimmedName.isEmpty {
            return "\(trimmedNickname)/\(trimmedName)\(generationText)"
        }
        if !trimmedNickname.isEmpty {
            return "\(trimmedNickname)\(generationText)"
        }
        return "\(trimmedName)\(generationText)"
    }

    private var generationOrdinalText: String {
        guard let gen = Int(generation), gen > 0 else { return "" }
        return "-\(generation)\(generationOrdinalSuffix)"
    }

    private var generationOrdinalSuffix: String {
        guard let gen = Int(generation) else { return "th" }
        let suffixBase = gen % 100
        if (11...13).contains(suffixBase) { return "th" }
        switch gen % 10 {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }

    /// NoticeChip에 표시할 공지 타입
    public var noticeType: NoticeType {
        // 파트 공지인 경우
        if case .part = category {
            return .part
        }
        
        // scope에 따라 구분
        switch scope {
        case .central:
            return .core
        case .branch:
            return .branch
        case .campus:
            return .campus
        }
    }
    
    public init(
        id: String,
        generation: String,
        scope: NoticeScope,
        category: NoticeCategory,
        isMustRead: Bool,
        title: String,
        content: String,
        authorID: String,
        authorMemberId: String? = nil,
        authorNickname: String? = nil,
        authorName: String,
        authorImageURL: String?,
        createdAt: Date,
        updatedAt: Date?,
        targetAudience: TargetAudience,
        hasPermission: Bool,
        images: [String],
        imageItems: [NoticeAttachmentImage] = [],
        links: [String],
        vote: NoticeVote?
    ) {
        self.id = id
        self.generation = generation
        self.scope = scope
        self.category = category
        self.isMustRead = isMustRead
        self.title = title
        self.content = content
        self.authorID = authorID
        self.authorMemberId = authorMemberId
        self.authorNickname = authorNickname
        self.authorName = authorName
        self.authorImageURL = authorImageURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.targetAudience = targetAudience
        self.hasPermission = hasPermission
        self.images = images
        self.imageItems = imageItems
        self.links = links
        self.vote = vote
    }
}

/// 공지 첨부 이미지 메타데이터
public struct NoticeAttachmentImage: Equatable, Hashable, Identifiable {
    public let id: String
    public let url: String
    
    public init(id: String, url: String) {
        self.id = id
        self.url = url
    }
}


// MARK: - TargetAudienc
/// 공지 수신 대상
public struct TargetAudience: Equatable, Hashable {
    public let generation: String
    public let scope: NoticeScope
    public let parts: [UMCPartType]
    public let chapterId: String?
    public let schoolId: String?
    public let branches: [String]
    public let schools: [String]

    public init(
        generation: String,
        scope: NoticeScope,
        parts: [UMCPartType],
        chapterId: String? = nil,
        schoolId: String? = nil,
        branches: [String],
        schools: [String]
    ) {
        self.generation = generation
        self.scope = scope
        self.parts = parts
        self.chapterId = chapterId
        self.schoolId = schoolId
        self.branches = branches
        self.schools = schools
    }
}

extension TargetAudience {
    /// 전체 대상 (기본값)
    public static func all(generation: String, scope: NoticeScope) -> TargetAudience {
        TargetAudience(
            generation: generation,
            scope: scope,
            parts: [],
            chapterId: nil,
            schoolId: nil,
            branches: [],
            schools: []
        )
    }
}


// MARK: - ImageViewerItem
/// fullScreenCover에서 Identifiable 사용을 위한 래퍼
public struct ImageViewerItem: Identifiable {
    public let id = UUID()
    public let index: String
}


// MARK: - NoticeVote

/// 공지사항 투표
public struct NoticeVote: Equatable, Identifiable, Hashable {
    public let id: String
    public let question: String
    public let options: [VoteOption]
    public let startDate: Date
    public let endDate: Date
    /// 복수 선택 허용 여부
    public let allowMultipleChoices: Bool
    /// 익명 투표 여부
    public let isAnonymous: Bool
    /// 현재 사용자가 투표한 옵션 ID 목록
    public let userVotedOptionIds: [String]
    /// 투표 상태 (서버 제공)
    public let status: VoteStatus
    /// 전체 참여자 수 (서버 제공) — 복수 선택 시 voteCount 합과 다를 수 있음
    public let totalParticipants: String

    public init(
        id: String,
        question: String,
        options: [VoteOption],
        startDate: Date,
        endDate: Date,
        allowMultipleChoices: Bool,
        isAnonymous: Bool,
        userVotedOptionIds: [String],
        status: VoteStatus? = nil,
        totalParticipants: String? = nil
    ) {
        self.id = id
        self.question = question
        self.options = options
        self.startDate = startDate
        self.endDate = endDate
        self.allowMultipleChoices = allowMultipleChoices
        self.isAnonymous = isAnonymous
        self.userVotedOptionIds = userVotedOptionIds
        self.status = status
            ?? VoteStatus.fallback(now: .now, startsAt: startDate, endsAt: endDate)
        self.totalParticipants = totalParticipants
              ?? String(options.reduce(0) { $0 + (Int($1.voteCount) ?? 0) })
    }

    /// 옵션별 voteCount 합계 (복수 선택 시 totalParticipants와 다름)
    public var totalVotes: Int {
          options.reduce(0) { $0 + (Int($1.voteCount) ?? 0) }
      }

    /// 투표 종료 여부
    public var isEnded: Bool {
        status == .ended
    }

    /// 사용자 투표 여부
    public var hasUserVoted: Bool {
        !userVotedOptionIds.isEmpty
    }
}

/// 투표 옵션
public struct VoteOption: Equatable, Identifiable, Hashable {
    public let id: String
    public let title: String
    public let voteCount: String
    public let selectedMemberIds: [String]
    /// 옵션 득표율 (서버 계산값, 0.0 ~ 100.0)
    public let voteRate: String?

    public init(
        id: String,
        title: String,
        voteCount: String,
        selectedMemberIds: [String] = [],
        voteRate: String? = nil
    ) {
        self.id = id
        self.title = title
        self.voteCount = voteCount
        self.selectedMemberIds = selectedMemberIds
        self.voteRate = voteRate
    }

    /// 투표율 — 서버 voteRate 우선, 없으면 클라이언트 계산
    public func percentage(totalVotes: Int) -> Double {
        if let rate = voteRate, let r = Double(rate), r > 0 { return r }
        guard totalVotes > 0 else { return 0 }
        return Double(Int(voteCount) ?? 0) / Double(totalVotes) * 100
    }
}

/// 투표 상태 (서버 enum 매핑)
public enum VoteStatus: String {
    case notStarted = "NOT_STARTED"
    case active = "OPEN"
    case ended = "CLOSED"

    /// 미정의 raw value 또는 서버 미제공 시 fallback (시작/종료 시각 기반)
    public static func fallback(now: Date, startsAt: Date, endsAt: Date) -> VoteStatus {
        if now < startsAt { return .notStarted }
        if now >= endsAt { return .ended }
        return .active
    }
}


// MARK: - ReadStatusTab

/// 공지 열람 현황 탭 (확인/미확인)
public enum ReadStatusTab: String, CaseIterable {
    case confirmed = "확인"
    case unconfirmed = "미확인"
}

// MARK: - NoticeReadStatus

/// 공지 열람 현황 전체 데이터
public struct NoticeReadStatus: Equatable {
    public let noticeId: String
    public let confirmedUsers: [ReadStatusUser]
    public let unconfirmedUsers: [ReadStatusUser]
    
    /// 확인한 사람 수
    public var confirmedCount: String {
        String(confirmedUsers.count)
    }
    
    /// 미확인한 사람 수
    public var unconfirmedCount: String {
        String(unconfirmedUsers.count)
    }
    
    /// 전체 대상자 수
    public var totalCount: String {
        confirmedCount + unconfirmedCount
    }
    
    /// 하단 메시지 (예: "이미 3명이 공지를 확인했습니다.")
    public var bottomMessage: String {
        "이미 \(confirmedCount)명이 공지를 확인했습니다."
    }
    
    public init(noticeId: String, confirmedUsers: [ReadStatusUser], unconfirmedUsers: [ReadStatusUser]) {
        self.noticeId = noticeId
        self.confirmedUsers = confirmedUsers
        self.unconfirmedUsers = unconfirmedUsers
    }
}


// MARK: - ReadStatusUser

/// 공지 열람 현황 - 사용자 정보
public struct ReadStatusUser: Equatable, Identifiable {
    public let id: String
    public let name: String
    public let nickName: String
    public let part: String
    public let branch: String
    public let campus: String
    public let profileImageURL: String?
    public let isRead: Bool
    
    /// NoticeReadStatusItemModel로 변환
    public func toItemModel() -> NoticeReadStatusItemModel {
        NoticeReadStatusItemModel(
            profileImageURL: profileImageURL,
            userName: name,
            nickName: nickName,
            part: part,
            location: branch,
            campus: campus,
            isRead: isRead
        )
    }
    
    public init(
        id: String,
        name: String,
        nickName: String,
        part: String,
        branch: String,
        campus: String,
        profileImageURL: String?,
        isRead: Bool
    ) {
        self.id = id
        self.name = name
        self.nickName = nickName
        self.part = part
        self.branch = branch
        self.campus = campus
        self.profileImageURL = profileImageURL
        self.isRead = isRead
    }
}

// MARK: - ReadStatusFilterType

/// 공지 열람 현황 필터 타입
public enum ReadStatusFilterType: String, CaseIterable, Identifiable {
    case all = "전체 보기"
    case branch = "지부별 보기"
    case school = "학교별 보기"
    
    public var id: String { rawValue }

    /// 열람 현황 필터 메뉴 아이콘
    public var iconName: String {
        switch self {
        case .all:
            return "line.3.horizontal.decrease"
        case .branch:
            return "mappin.and.ellipse"
        case .school:
            return "graduationcap"
        }
    }
}
