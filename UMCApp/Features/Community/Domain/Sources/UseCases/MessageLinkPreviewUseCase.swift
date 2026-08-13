//
//  MessageLinkPreviewUseCase.swift
//  CommunityDomain
//

import Foundation
import NoticeDomain

/// 링크 카드에 그릴 메타.
public struct MessageLinkPreview: Equatable {

    // MARK: - Property

    public let link: MessageLink
    public let title: String
    /// 본문 요약. 원문에 내용이 없으면 빈 문자열이고, 카드는 이때 요약 줄을 생략한다.
    public let summary: String
    /// 공지 링크일 때만 채워진다 — 카드 탭이 상세 화면으로 넘길 모델.
    ///
    /// 공지 상세 목적지가 `NoticeDetail` 을 연관값으로 받기 때문에, 탭 시점에 다시 조회하지
    /// 않도록 메타를 만들 때 받아 둔 모델을 그대로 들고 다닌다.
    public let notice: NoticeDetail?

    // MARK: - Init

    public init(link: MessageLink, title: String, summary: String, notice: NoticeDetail?) {
        self.link = link
        self.title = title
        self.summary = summary
        self.notice = notice
    }
}

public protocol MessageLinkPreviewUseCaseProtocol {
    /// - Throws: 조회 실패. 호출부는 카드를 포기하고 원문 텍스트 링크로 되돌린다.
    func preview(for link: MessageLink) async throws -> MessageLinkPreview
}

/// 메시지 본문의 내부 링크를 카드용 메타로 바꾼다.
///
/// 링크 카드 전용 메타 엔드포인트가 없어 각 도메인의 상세 조회를 그대로 쓴다. 공지 상세는
/// 본문·첨부까지 실어 오므로 카드 한 장 치고는 과하지만, 없는 경로를 지어내지 않는 쪽을 택했다
/// (경량 메타 엔드포인트는 후속 과제).
public final class MessageLinkPreviewUseCase: MessageLinkPreviewUseCaseProtocol {

    // MARK: - Property

    private let threadRepository: CommunityThreadRepositoryProtocol
    private let noticeRepository: NoticeRepositoryProtocol
    /// 링크 하나당 한 번만 조회한다. 메시지 목록이 lazy 라 셀이 재사용될 때마다 `task` 가 다시
    /// 뜨고, 캐시가 없으면 스크롤 왕복마다 상세 조회가 반복된다.
    private var cache: [MessageLink: MessageLinkPreview] = [:]

    // MARK: - Init

    public init(
        threadRepository: CommunityThreadRepositoryProtocol,
        noticeRepository: NoticeRepositoryProtocol
    ) {
        self.threadRepository = threadRepository
        self.noticeRepository = noticeRepository
    }

    // MARK: - Function

    public func preview(for link: MessageLink) async throws -> MessageLinkPreview {
        if let cached = cache[link] { return cached }

        let preview: MessageLinkPreview
        switch link {
        case .thread(let id):
            let thread = try await threadRepository.fetchThread(threadId: id)
            preview = MessageLinkPreview(
                link: link,
                title: thread.title,
                summary: Self.singleLine(thread.description),
                notice: nil
            )
        case .notice(let id):
            let notice = try await noticeRepository.getDetailNotice(noticeId: id)
            preview = MessageLinkPreview(
                link: link,
                title: notice.title,
                summary: Self.singleLine(notice.content),
                notice: notice
            )
        }

        cache[link] = preview
        return preview
    }

    // MARK: - Private

    /// 카드 요약은 두 줄로 잘리므로, 줄바꿈이 남아 있으면 빈 줄만 보이고 내용이 안 보인다.
    private static func singleLine(_ text: String) -> String {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
