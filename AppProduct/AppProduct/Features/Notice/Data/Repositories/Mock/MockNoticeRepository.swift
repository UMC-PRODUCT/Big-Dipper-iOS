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
        try await Task.sleep(for: .milliseconds(200))
        let content = try MockNoticeDTOFactory.makeAll()
        return NoticePageDTO(
            content: content,
            page: "0",
            size: "\(content.count)",
            totalElements: "\(content.count)",
            totalPages: "1",
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
        try await Task.sleep(for: .milliseconds(200))
        let keyword = keyword.lowercased()
        let content = try MockNoticeDTOFactory.makeAll().filter {
            $0.title.lowercased().contains(keyword) ||
            $0.content.lowercased().contains(keyword)
        }
        return NoticePageDTO(
            content: content,
            page: "0",
            size: "\(content.count)",
            totalElements: "\(content.count)",
            totalPages: "1",
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

// MARK: - Mock DTO Factory

/// NoticeDTO에는 memberwise init이 없어 JSON 디코딩으로 Mock 인스턴스를 생성합니다.
private enum MockNoticeDTOFactory {

    static func makeAll() throws -> [NoticeDTO] {
        let dtos = try [
            makeDTO(
                id: "1",
                title: "9th UMC Hackathon 모집 신청 안내",
                content: "챌린저 여러분께서 기다리시던 9th UMC Hackathon이 진행됩니다!",
                viewCount: 445,
                shouldSendNotification: true,
                authorNickname: "사과",
                authorName: "김아요",
                targetGisu: "9",
                targetGisuId: "9",
                targetChapterId: nil,
                targetSchoolId: nil,
                chapterName: nil,
                schoolName: nil
            ),
            makeDTO(
                id: "2",
                title: "🗣️ 9th UMC 동아리 연합 컨퍼런스 신청 모집 안내",
                content: "2026년 9th UMCON이 다가오고 있습니다!",
                viewCount: 421,
                shouldSendNotification: true,
                authorNickname: "사과",
                authorName: "김아요",
                targetGisu: "9",
                targetGisuId: "9",
                targetChapterId: nil,
                targetSchoolId: nil,
                chapterName: nil,
                schoolName: nil
            ),
            makeDTO(
                id: "3",
                title: "[투표] 9기 기말고사 뒤풀이 메뉴 선정 안내",
                content: "9기 UMC대 챌린저 여러분 안녕하세요! 기말고사 뒤풀이 회식 메뉴를 결정하고자 합니다.",
                viewCount: 32,
                shouldSendNotification: false,
                authorNickname: "애플",
                authorName: "박사과",
                targetGisu: "9",
                targetGisuId: "9",
                targetChapterId: "1",
                targetSchoolId: "1",
                chapterName: "Nova",
                schoolName: "UMC 대학교"
            ),
            makeDTO(
                id: "4",
                title: "9기 해커톤 현장 사진 공유",
                content: "지난 주말 진행된 해커톤 현장 사진을 공유합니다.",
                viewCount: 256,
                shouldSendNotification: false,
                authorNickname: "너드",
                authorName: "이서버",
                targetGisu: "9",
                targetGisuId: "9",
                targetChapterId: nil,
                targetSchoolId: nil,
                chapterName: nil,
                schoolName: nil
            )
        ]
        return dtos
    }

    private static func makeDTO(
        id: String,
        title: String,
        content: String,
        viewCount: Int,
        shouldSendNotification: Bool,
        authorNickname: String,
        authorName: String,
        targetGisu: String?,
        targetGisuId: String,
        targetChapterId: String?,
        targetSchoolId: String?,
        chapterName: String?,
        schoolName: String?
    ) throws -> NoticeDTO {
        let createdAt = ISO8601DateFormatter().string(from: Date())
        var dict: [String: Any] = [
            "id": id,
            "title": title,
            "content": content,
            "shouldSendNotification": shouldSendNotification,
            "viewCount": "\(viewCount)",
            "createdAt": createdAt,
            "authorNickname": authorNickname,
            "authorName": authorName,
            "targetInfo": [
                "targetGisu": targetGisu as Any,
                "targetGisuId": targetGisuId,
                "targetChapterId": targetChapterId as Any,
                "targetSchoolId": targetSchoolId as Any,
                "chapterName": chapterName as Any,
                "schoolName": schoolName as Any
            ]
        ]
        if let authorChallengerId = Optional<String>.some("0") {
            dict["authorChallengerId"] = authorChallengerId
        }

        let data = try JSONSerialization.data(withJSONObject: dict, options: [])
        return try JSONDecoder().decode(NoticeDTO.self, from: data)
    }
}
