//
//  NoticeDetailModel.swift
//  AppProduct
//
//  Created by 이예지 on 2/2/26.
//

import Foundation
import SwiftUI

// MARK: - NoticeDetail

/// 공지사항 상세정보 엔티티
struct NoticeDetail: Equatable, Identifiable, Hashable {
    /// 공지 고유 ID
    let id: String
    /// 기수
    let generation: Int
    /// 공지 범위 (중앙/지부/교내)
    let scope: NoticeScope
    /// 공지 카테고리
    let category: NoticeCategory

    /// 필독 여부
    let isMustRead: Bool

    /// 공지 제목
    let title: String
    /// 공지 본문
    let content: String

    /// 작성자 ID
    let authorID: String
    /// 작성자 멤버 ID (authorMemberId)
    let authorMemberId: String?
    /// 작성자 닉네임
    let authorNickname: String?
    /// 작성자 이름
    let authorName: String
    /// 작성자 프로필 이미지 URL
    let authorImageURL: String?

    /// 생성일
    let createdAt: Date
    /// 수정일
    let updatedAt: Date?

    /// 수신 대상
    let targetAudience: TargetAudience

    /// 수정/삭제 권한 보유 여부
    let hasPermission: Bool

    /// 첨부 이미지 URL 목록
    let images: [String]
    /// 첨부 이미지 원본 메타데이터 (수정 화면의 교체 API 구성에 사용)
    var imageItems: [NoticeAttachmentImage] = []
    /// 첨부 링크 목록
    let links: [String]
    /// 첨부 투표
    let vote: NoticeVote?

    /// 작성자 표기 기본값 (닉네임/이름-xxth)
    var defaultAuthorDisplayName: String {
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
        guard generation > 0 else { return "" }
        return "-\(generation)\(generationOrdinalSuffix)"
    }

    private var generationOrdinalSuffix: String {
        let suffixBase = generation % 100
        if (11...13).contains(suffixBase) {
            return "th"
        }

        switch generation % 10 {
        case 1:
            return "st"
        case 2:
            return "nd"
        case 3:
            return "rd"
        default:
            return "th"
        }
    }

    /// NoticeChip에 표시할 공지 타입
    var noticeType: NoticeType {
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

    /// 목록/상세에서 공통으로 사용할 태그 목록
    var tags: [NoticeItemTag] {
        NoticeItemModel(
            noticeId: id,
            generation: generation,
            scope: scope,
            category: category,
            mustRead: isMustRead,
            isAlert: false,
            date: createdAt,
            title: title,
            content: content,
            writer: authorName,
            links: links,
            images: images,
            vote: vote,
            viewCount: 0,
            scopeDisplayName: targetAudience.branches.first,
            targetsAllGenerations: targetAudience.generation <= 0,
            parts: targetAudience.parts,
            isRead: false
        ).tags
    }

    init(
        id: String,
        generation: Int,
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
struct NoticeAttachmentImage: Equatable, Hashable, Identifiable {
    let id: String
    let url: String
}


// MARK: - TargetAudience
                                                                                                                                              
 /// 공지 수신 대상
struct TargetAudience: Equatable, Hashable {
    let generation: Int
    let scope: NoticeScope
    let parts: [UMCPartType]
    let chapterId: Int?
    let schoolId: Int?
    let branches: [String]
    let schools: [String]

    init(
        generation: Int,
        scope: NoticeScope,
        parts: [UMCPartType],
        chapterId: Int? = nil,
        schoolId: Int? = nil,
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
    
    /// 수신 대상 표시 텍스트
    ///
    /// 레거시 호환용 속성입니다. 신규 UI는 `NoticeDetail.tags`를 사용합니다.
    var displayText: String {
        NoticeDetail(
            id: "",
            generation: generation,
            scope: scope,
            category: parts.first.map { .part($0) } ?? .general,
            isMustRead: false,
            title: "",
            content: "",
            authorID: "",
            authorNickname: nil,
            authorName: "",
            authorImageURL: nil,
            createdAt: .now,
            updatedAt: nil,
            targetAudience: self,
            hasPermission: false,
            images: [],
            links: [],
            vote: nil
        )
        .tags
        .map(\.text)
        .joined(separator: " / ")
    }
}

extension TargetAudience {
    /// 전체 대상 (기본값)
    static func all(generation: Int, scope: NoticeScope) -> TargetAudience {
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
struct ImageViewerItem: Identifiable {
    let id = UUID()
    let index: Int
}


// MARK: - NoticeVote

/// 공지사항 투표
struct NoticeVote: Equatable, Identifiable, Hashable {
    let id: String
    let question: String
    let options: [VoteOption]
    let startDate: Date
    let endDate: Date
    /// 복수 선택 허용 여부
    let allowMultipleChoices: Bool
    /// 익명 투표 여부
    let isAnonymous: Bool
    /// 현재 사용자가 투표한 옵션 ID 목록
    let userVotedOptionIds: [String]
    /// 투표 상태 (서버 제공)
    let status: VoteStatus
    /// 전체 참여자 수 (서버 제공) — 복수 선택 시 voteCount 합과 다를 수 있음
    let totalParticipants: Int

    init(
        id: String,
        question: String,
        options: [VoteOption],
        startDate: Date,
        endDate: Date,
        allowMultipleChoices: Bool,
        isAnonymous: Bool,
        userVotedOptionIds: [String],
        status: VoteStatus? = nil,
        totalParticipants: Int? = nil
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
            ?? options.reduce(0) { $0 + $1.voteCount }
    }

    /// 옵션별 voteCount 합계 (복수 선택 시 totalParticipants와 다름)
    var totalVotes: Int {
        options.reduce(0) { $0 + $1.voteCount }
    }

    /// 투표 종료 여부
    var isEnded: Bool {
        status == .ended
    }

    /// 사용자 투표 여부
    var hasUserVoted: Bool {
        !userVotedOptionIds.isEmpty
    }

    /// 날짜 포맷 (MM.dd - MM.dd)
    var formattedPeriod: String {
        startDate.dateRange(to: endDate)
    }
}

/// 투표 옵션
struct VoteOption: Equatable, Identifiable, Hashable {
    let id: String
    let title: String
    let voteCount: Int
    let selectedMemberIds: [String]
    /// 옵션 득표율 (서버 계산값, 0.0 ~ 100.0)
    let voteRate: Double

    init(
        id: String,
        title: String,
        voteCount: Int,
        selectedMemberIds: [String] = [],
        voteRate: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.voteCount = voteCount
        self.selectedMemberIds = selectedMemberIds
        self.voteRate = voteRate ?? 0
    }

    /// 투표율 — 서버 voteRate 우선, 없으면 클라이언트 계산
    func percentage(totalVotes: Int) -> Double {
        if voteRate > 0 { return voteRate }
        guard totalVotes > 0 else { return 0 }
        return Double(voteCount) / Double(totalVotes) * 100
    }
}

/// 투표 상태 (서버 enum 매핑)
enum VoteStatus: String {
    case notStarted = "NOT_STARTED"
    case active = "OPEN"
    case ended = "CLOSED"

    /// 미정의 raw value 또는 서버 미제공 시 fallback (시작/종료 시각 기반)
    static func fallback(now: Date, startsAt: Date, endsAt: Date) -> VoteStatus {
        if now < startsAt { return .notStarted }
        if now >= endsAt { return .ended }
        return .active
    }
}


// MARK: - ReadStatusTab

/// 공지 열람 현황 탭 (확인/미확인)
enum ReadStatusTab: String, CaseIterable {
    case confirmed = "확인"
    case unconfirmed = "미확인"
}

// MARK: - NoticeReadStatus

/// 공지 열람 현황 전체 데이터
struct NoticeReadStatus: Equatable {
    let noticeId: String
    let confirmedUsers: [ReadStatusUser]
    let unconfirmedUsers: [ReadStatusUser]
    
    /// 확인한 사람 수
    var confirmedCount: Int {
        confirmedUsers.count
    }
    
    /// 미확인한 사람 수
    var unconfirmedCount: Int {
        unconfirmedUsers.count
    }
    
    /// 전체 대상자 수
    var totalCount: Int {
        confirmedCount + unconfirmedCount
    }
    
    /// 하단 메시지 (예: "이미 3명이 공지를 확인했습니다.")
    var bottomMessage: String {
        "이미 \(confirmedCount)명이 공지를 확인했습니다."
    }
}


// MARK: - ReadStatusUser

/// 공지 열람 현황 - 사용자 정보
struct ReadStatusUser: Equatable, Identifiable {
    let id: String
    let name: String
    let nickName: String
    let part: String
    let branch: String
    let campus: String
    let profileImageURL: String?
    let isRead: Bool
    
    /// NoticeReadStatusItemModel로 변환
    func toItemModel() -> NoticeReadStatusItemModel {
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
}

// MARK: - ReadStatusFilterType

/// 공지 열람 현황 필터 타입
enum ReadStatusFilterType: String, CaseIterable, Identifiable {
    case all = "전체 보기"
    case branch = "지부별 보기"
    case school = "학교별 보기"
    
    var id: String { rawValue }

    /// 열람 현황 필터 메뉴 아이콘
    var iconName: String {
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
