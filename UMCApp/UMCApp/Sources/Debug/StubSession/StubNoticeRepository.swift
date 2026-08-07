//
//  StubNoticeRepository.swift
//  UMCApp
//
//  Created by jaewon Lee on 8/3/26.
//

#if DEBUG
import Foundation
import NoticeDomain

/// stub 세션에서 지원하지 않는 쓰기 동작에 대한 에러.
///
/// ErrorHandler 전역 Alert로 표면화되어 "stub 미지원" 사실이 UI에서 바로 드러난다.
enum StubSessionError: LocalizedError {
    case unsupported(action: String)

    var errorDescription: String? {
        switch self {
        case .unsupported(let action):
            "Stub 세션에서는 지원하지 않는 동작입니다: \(action)"
        }
    }
}

/// 카카오 로그인 서버 미등록 기간 한정 공지 Repository stub (절대규칙 #5).
///
/// 홈 최근 공지 5건(`FetchRecentNoticesUseCase` → `getAllNotices`)과 공지 상세
/// (`NoticeUseCase` → `getDetailNotice`)가 같은 프로토콜을 공유하므로 이 stub 하나로
/// 목록·상세가 함께 동작한다. 읽기는 픽스처, 참여형(읽음/투표)은 no-op 성공,
/// 생성·수정·삭제·리마인더는 `StubSessionError`를 던져 미지원임을 알린다.
struct StubNoticeRepository: NoticeRepositoryProtocol {

    // MARK: - 공지 조회 (픽스처)

    func getAllNotices(request: NoticeListRequest) async throws -> NoticePage {
        NoticePage(
            items: StubSessionFixtures.notices,
            hasNext: false,
            totalElements: String(StubSessionFixtures.notices.count)
        )
    }

    func getDetailNotice(noticeId: String) async throws -> NoticeDetail {
        if let detail = StubSessionFixtures.noticeDetails[noticeId] {
            return detail
        }
        guard let fallback = StubSessionFixtures.notices.first else {
            throw StubSessionError.unsupported(action: "공지 상세 조회 (\(noticeId))")
        }
        return fallback.toNoticeDetail()
    }

    func getReadStatics(noticeId: String) async throws -> NoticeReadStatics {
        StubSessionFixtures.readStatics
    }

    func getReadStatusList(
        noticeId: String,
        cursorId: String,
        filterType: String,
        organizationIds: [String],
        status: String
    ) async throws -> NoticeReadStatusPage {
        StubSessionFixtures.readStatusPage
    }

    func searchNotice(
        keyword: String,
        request: NoticeListRequest
    ) async throws -> NoticePage {
        let matched = StubSessionFixtures.notices.filter {
            $0.title.localizedCaseInsensitiveContains(keyword)
                || $0.content.localizedCaseInsensitiveContains(keyword)
        }
        return NoticePage(
            items: matched,
            hasNext: false,
            totalElements: String(matched.count)
        )
    }

    // MARK: - 참여형 액션 (no-op 성공)

    func readNotice(noticeId: String) async throws {}

    func submitVoteResponse(noticeId: String, optionIds: [String]) async throws {}

    func updateVoteResponse(noticeId: String, optionIds: [String]) async throws {}

    // MARK: - 생성/수정/삭제 (미지원)

    func createNotice(
        title: String,
        content: String,
        shouldNotify: Bool,
        targetInfo: NoticeTargetInfo,
        links: [String],
        imageIds: [String]
    ) async throws -> NoticeDetail {
        throw StubSessionError.unsupported(action: "공지 생성")
    }

    func addVote(
        noticeId: String,
        title: String,
        isAnonymous: Bool,
        allowMultipleChoice: Bool,
        startsAt: Date,
        endsAtExclusive: Date,
        options: [String]
    ) async throws -> String {
        throw StubSessionError.unsupported(action: "투표 추가")
    }

    func addLink(noticeId: String, links: [String]) async throws -> NoticeItemModel {
        throw StubSessionError.unsupported(action: "링크 추가")
    }

    func addImage(noticeId: String, imageIds: [String]) async throws -> NoticeItemModel {
        throw StubSessionError.unsupported(action: "이미지 추가")
    }

    func sendReminder(noticeId: String, targetIds: [String]) async throws {
        throw StubSessionError.unsupported(action: "리마인더 발송")
    }

    func updateNotice(
        noticeId: String,
        title: String,
        content: String
    ) async throws -> NoticeDetail {
        throw StubSessionError.unsupported(action: "공지 수정")
    }

    func updateLinks(noticeId: String, links: [String]) async throws -> NoticeDetail {
        throw StubSessionError.unsupported(action: "링크 수정")
    }

    func updateImages(noticeId: String, imageIds: [String]) async throws -> NoticeDetail {
        throw StubSessionError.unsupported(action: "이미지 수정")
    }

    func deleteNotice(noticeId: String) async throws {
        throw StubSessionError.unsupported(action: "공지 삭제")
    }

    func deleteVote(noticeId: String) async throws {
        throw StubSessionError.unsupported(action: "투표 삭제")
    }
}
#endif
