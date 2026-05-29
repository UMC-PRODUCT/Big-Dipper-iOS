//
//  MockNoticeRepository.swift
//  NoticeData
//
//  Created by 이예지 on 5/30/26.
//

import Foundation
import UMCFoundation
import NoticeDomain

/// 프리뷰 및 테스트용 Notice Repository Mock 구현체
///
/// 네트워크 없이 NoticeMockData 기반 정적 데이터를 반환합니다.
public final class MockNoticeRepository: NoticeRepositoryProtocol {

    // MARK: - 공지 생성

    public func createNotice(
        title: String,
        content: String,
        shouldNotify: Bool,
        targetInfo: NoticeTargetInfo,
        links: [String],
        imageIds: [String]
    ) async throws -> NoticeDetail {
        throw DomainError.insufficientPermission(required: "인증")
    }

    // TODO: 사용되는 곳 없음, 검토 필요
//    public func postNotice(body: PostNoticeRequestDTO) async throws -> NoticeItemModel {
//        throw DomainError.insufficientPermission(required: "인증")
//    }

    public func addVote(
        noticeId: String,
        title: String,
        isAnonymous: Bool,
        allowMultipleChoice: Bool,
        startsAt: Date,
        endsAtExclusive: Date,
        options: [String]
    ) async throws -> String {
        throw DomainError.insufficientPermission(required: "인증")
    }

    public func addLink(noticeId: String, links: [String]) async throws -> NoticeItemModel {
        throw DomainError.insufficientPermission(required: "인증")
    }

    public func addImage(noticeId: String, imageIds: [String]) async throws -> NoticeItemModel {
        throw DomainError.insufficientPermission(required: "인증")
    }

    public func sendReminder(noticeId: String, targetIds: [String]) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }

    public func readNotice(noticeId: String) async throws {}

    public func submitVoteResponse(noticeId: String, optionIds: [String]) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }

    public func updateVoteResponse(noticeId: String, optionIds: [String]) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }

    // MARK: - 공지 수정

    public func updateNotice(
        noticeId: String,
        title: String,
        content: String
    ) async throws -> NoticeDetail {
        throw DomainError.insufficientPermission(required: "인증")
    }

    public func updateLinks(
        noticeId: String,
        links: [String]
    ) async throws -> NoticeDetail {
        throw DomainError.insufficientPermission(required: "인증")
    }

    public func updateImages(
        noticeId: String,
        imageIds: [String]
    ) async throws -> NoticeDetail {
        throw DomainError.insufficientPermission(required: "인증")
    }

    // MARK: - 공지 조회

    public func getAllNotices(request: NoticeListRequest) async throws -> NoticePage {
        NoticePage(
            items: [],
            hasNext: false,
            totalElements: "0"
        )
    }

    public func getDetailNotice(noticeId: String) async throws -> NoticeDetail {
        throw DomainError.noticeNotFound
    }

    public func getReadStatics(noticeId: String) async throws -> NoticeReadStatics {
        NoticeReadStatics(
            totalCount: "0",
            readCount: "0",
            unreadCount: "0",
            readRate: "0"
        )
    }

    public func getReadStatusList(
        noticeId: String,
        cursorId: String,
        filterType: String,
        organizationIds: [String],
        status: String
    ) async throws -> NoticeReadStatusPage {
        NoticeReadStatusPage(
            users: [],
            nextCursor: "0",
            hasNext: false)
    }

    public func searchNotice(
        keyword: String,
        request: NoticeListRequest
    ) async throws -> NoticePage {
        NoticePage(
            items: [],
            hasNext: false,
            totalElements: "0"
        )
    }

    // MARK: - 공지 삭제

    public func deleteNotice(noticeId: String) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }

    public func deleteVote(noticeId: String) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }
}
