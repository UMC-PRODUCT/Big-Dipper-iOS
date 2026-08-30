//
//  WatchNotice.swift
//  CoreWatchConnectivity
//
//  Created by euijjang97 on 8/29/26.
//

import Foundation

// MARK: - WatchNotice

/// 워치 공지 목록·본문이 쓰는 최소 필드.
///
/// 원본은 `NoticeItemModel` 이지만 Core 는 Feature 에 의존할 수 없으므로 자체 값 타입으로 둔다.
/// 워치가 그리지 않는 필드(조회수·파트·링크·이미지·투표)는 싣지 않는다.
public struct WatchNotice: Codable, Sendable, Equatable, Identifiable {

    // MARK: - Property

    public var id: String { noticeId }
    public let noticeId: String
    public let title: String
    /// 본문 전문. 워치가 본문을 스크롤해 읽고 확인 CTA 를 누른다.
    public let content: String
    /// `NoticeItemModel.displayWriter` 결과를 그대로 싣는다 — 이름/닉네임 조합 규칙은 iPhone 소유다.
    public let writer: String
    /// `NoticeItemModel.date`.
    public let postedAt: Date
    /// `NoticeItemModel.mustRead` — 필수확인 공지. 워치 상단 고정 배너의 근거다.
    public let isMustRead: Bool
    /// `NoticeItemModel.isAlert` — 긴급 표시. 좌측 색바 신호의 근거다.
    public let isAlert: Bool
    public let isRead: Bool

    // MARK: - Init

    public init(
        noticeId: String,
        title: String,
        content: String,
        writer: String,
        postedAt: Date,
        isMustRead: Bool,
        isAlert: Bool,
        isRead: Bool
    ) {
        self.noticeId = noticeId
        self.title = title
        self.content = content
        self.writer = writer
        self.postedAt = postedAt
        self.isMustRead = isMustRead
        self.isAlert = isAlert
        self.isRead = isRead
    }
}

// MARK: - WatchNoticeRead

/// 워치에서 공지를 읽었다는 확인. 워치 → iPhone 단방향.
///
/// `memberId` 를 싣지 않는다 — 신원은 iPhone 이 안다
/// (`NoticeReadRepositoryProtocol.markAsRead(noticeId:memberId:)` 의 `memberId` 는 iPhone 이 채운다).
/// 워치에 신원 정보를 두지 않는다는 원칙이기도 하다.
public struct WatchNoticeRead: Codable, Sendable, Equatable {

    // MARK: - Property

    public let noticeId: String
    /// 읽은 시각. 오프라인 큐로 늦게 도착할 수 있어 도착 시각으로 대체할 수 없다.
    public let readAt: Date

    // MARK: - Init

    public init(noticeId: String, readAt: Date) {
        self.noticeId = noticeId
        self.readAt = readAt
    }
}
