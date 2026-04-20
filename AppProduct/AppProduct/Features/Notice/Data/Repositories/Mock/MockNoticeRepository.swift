//
//  MockNoticeRepository.swift
//  AppProduct
//

import Foundation

/// 게스트 세션 및 프리뷰용 Notice Repository Mock 구현체
///
/// 네트워크 없이 NoticeMockData 기반 정적 데이터를 반환합니다.
final class MockNoticeRepository: NoticeRepositoryProtocol {

    // MARK: - 공지 생성

    func createNotice(
        body: PostNoticeRequestDTO,
        links: [String],
        imageIds: [String]
    ) async throws -> NoticeDetail {
        try await mockDetail(noticeId: 0)
    }

    func postNotice(body: PostNoticeRequestDTO) async throws -> NoticeItemModel {
        guard let item = NoticeMockData.items.first else {
            throw DomainError.noticeNotFound
        }
        return item
    }

    func addVote(
        noticeId: Int,
        body: AddVoteRequestDTO
    ) async throws -> AddVoteResponseDTO {
        let json = #"{"noticeVoteId":"0","voteId":"0"}"#
        return try JSONDecoder().decode(AddVoteResponseDTO.self, from: Data(json.utf8))
    }

    func addLink(noticeId: Int, links: [String]) async throws -> NoticeItemModel {
        guard let item = NoticeMockData.items.first else {
            throw DomainError.noticeNotFound
        }
        return item
    }

    func addImage(noticeId: Int, imageIds: [String]) async throws -> NoticeItemModel {
        guard let item = NoticeMockData.items.first else {
            throw DomainError.noticeNotFound
        }
        return item
    }

    func sendReminder(noticeId: Int, targetIds: [Int]) async throws {}

    func readNotice(noticeId: Int) async throws {}

    func submitVoteResponse(voteId: Int, optionIds: [Int]) async throws {}

    func updateVoteResponse(voteId: Int, optionIds: [Int]) async throws {}

    // MARK: - 공지 수정

    func updateNotice(
        noticeId: Int,
        body: UpdateNoticeRequestDTO
    ) async throws -> NoticeDetail {
        try await mockDetail(noticeId: noticeId)
    }

    func updateLinks(
        noticeId: Int,
        links: [String]
    ) async throws -> NoticeDetail {
        try await mockDetail(noticeId: noticeId)
    }

    func updateImages(
        noticeId: Int,
        imageIds: [String]
    ) async throws -> NoticeDetail {
        try await mockDetail(noticeId: noticeId)
    }

    // MARK: - 공지 조회

    func getAllNotices(
        request: NoticeListRequestDTO
    ) async throws -> NoticePageDTO<NoticeDTO> {
        NoticePageDTO(
            content: [],
            page: "0",
            size: "20",
            totalElements: "0",
            totalPages: "0",
            hasNext: false,
            hasPrevious: false
        )
    }

    func getDetailNotice(noticeId: Int) async throws -> NoticeDetail {
        guard let item = NoticeMockData.items.first else {
            throw DomainError.noticeNotFound
        }
        return NoticeDetail(
            id: "\(noticeId)",
            generation: item.generation,
            scope: item.scope,
            category: item.category,
            isMustRead: item.mustRead,
            title: item.title,
            content: item.content,
            authorID: "0",
            authorNickname: nil,
            authorName: item.writer,
            authorImageURL: nil,
            createdAt: item.date,
            updatedAt: nil,
            targetAudience: TargetAudience.all(generation: item.generation, scope: item.scope),
            hasPermission: false,
            images: item.images,
            links: item.links,
            vote: item.vote
        )
    }

    func getReadStatics(noticeId: Int) async throws -> NoticeReadStaticsDTO {
        NoticeReadStaticsDTO(
            totalCount: "0",
            readCount: "0",
            unreadCount: "0",
            readRate: "0"
        )
    }

    func getReadStatusList(
        noticeId: Int,
        cursorId: Int,
        filterType: String,
        organizationIds: [Int],
        status: String
    ) async throws -> NoticeReadStatusResponseDTO {
        let json = """
        {"content":[],"nextCursor":"0","hasNext":false}
        """
        let data = Data(json.utf8)
        return try JSONDecoder().decode(NoticeReadStatusResponseDTO.self, from: data)
    }

    func searchNotice(
        keyword: String,
        request: NoticeListRequestDTO
    ) async throws -> NoticePageDTO<NoticeDTO> {
        NoticePageDTO(
            content: [],
            page: "0",
            size: "20",
            totalElements: "0",
            totalPages: "0",
            hasNext: false,
            hasPrevious: false
        )
    }

    // MARK: - 공지 삭제

    func deleteNotice(noticeId: Int) async throws {}

    func deleteVote(noticeId: Int) async throws {}

    // MARK: - Private

    private func mockDetail(noticeId: Int) async throws -> NoticeDetail {
        guard let item = NoticeMockData.items.first else {
            throw DomainError.noticeNotFound
        }
        return NoticeDetail(
            id: "\(noticeId)",
            generation: item.generation,
            scope: item.scope,
            category: item.category,
            isMustRead: item.mustRead,
            title: item.title,
            content: item.content,
            authorID: "0",
            authorNickname: nil,
            authorName: item.writer,
            authorImageURL: nil,
            createdAt: item.date,
            updatedAt: nil,
            targetAudience: TargetAudience.all(generation: item.generation, scope: item.scope),
            hasPermission: false,
            images: item.images,
            links: item.links,
            vote: item.vote
        )
    }
}
