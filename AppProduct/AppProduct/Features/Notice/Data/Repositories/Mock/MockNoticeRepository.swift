//
//  MockNoticeRepository.swift
//  AppProduct
//

import Foundation

/// 프리뷰 및 테스트용 Notice Repository Mock 구현체
///
/// 네트워크 없이 NoticeMockData 기반 정적 데이터를 반환합니다.
final class MockNoticeRepository: NoticeRepositoryProtocol {

    // MARK: - 공지 생성

    func createNotice(
        body: PostNoticeRequestDTO,
        links: [String],
        imageIds: [String]
    ) async throws -> NoticeDetail {
        throw DomainError.insufficientPermission(required: "인증")
    }

    func postNotice(body: PostNoticeRequestDTO) async throws -> NoticeItemModel {
        throw DomainError.insufficientPermission(required: "인증")
    }

    func addVote(
        noticeId: Int,
        body: AddVoteRequestDTO
    ) async throws -> AddVoteResponseDTO {
        throw DomainError.insufficientPermission(required: "인증")
    }

    func addLink(noticeId: Int, links: [String]) async throws -> NoticeItemModel {
        throw DomainError.insufficientPermission(required: "인증")
    }

    func addImage(noticeId: Int, imageIds: [String]) async throws -> NoticeItemModel {
        throw DomainError.insufficientPermission(required: "인증")
    }

    func sendReminder(noticeId: Int, targetIds: [Int]) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }

    func readNotice(noticeId: Int) async throws {}

    func submitVoteResponse(noticeId: Int, optionIds: [Int]) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }

    func updateVoteResponse(noticeId: Int, optionIds: [Int]) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }

    // MARK: - 공지 수정

    func updateNotice(
        noticeId: Int,
        body: UpdateNoticeRequestDTO
    ) async throws -> NoticeDetail {
        throw DomainError.insufficientPermission(required: "인증")
    }

    func updateLinks(
        noticeId: Int,
        links: [String]
    ) async throws -> NoticeDetail {
        throw DomainError.insufficientPermission(required: "인증")
    }

    func updateImages(
        noticeId: Int,
        imageIds: [String]
    ) async throws -> NoticeDetail {
        throw DomainError.insufficientPermission(required: "인증")
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

    func deleteNotice(noticeId: Int) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }

    func deleteVote(noticeId: Int) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }
}
