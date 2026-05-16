//
//  NoticeRepository.swift
//  NoticeData
//
//  Created by 이예지 on 5/17/26.
//

import Foundation
import CoreNetwork
import NoticeDomain
import UMCFoundation

// MARK: - NoticeRepositoryProtocol

/// 공지사항 Repository 구현체
///
/// 공지 CRUD, 열람 처리, 리마인더, 검색 등 공지 관련 전체 API를 처리합니다.
public struct NoticeRepository: NoticeRepositoryProtocol {
    
    // MARK: - Property
    private let adapter: MoyaNetworkAdapter
    
    // MARK: - Initializer
    public init(adapter: MoyaNetworkAdapter) {
        self.adapter = adapter
    }
        
    // MARK: - 공지 생성
    /// 공지사항 완전 생성 (links, images 포함) → 상세 조회 반환
    public func createNotice(
        body: PostNoticeRequestDTO,
        links: [String] = [],
        imageIds: [String] = []
    ) async throws -> NoticeDetail {
        let response = try await adapter.request(NoticeRouter.postNotice(body: body))
        
        let apiResponse = try JSONDecoder().decode(
            APIResponse<NoticeCreateResponseDTO>.self,
            from: response.data
        )
        let noticeId = try apiResponse.unwrap().noticeId
        
        if !links.isEmpty {
            _ = try await adapter.request(
                NoticeRouter.addLink(
                    noticeId: noticeId,
                    body: NoticeLinksRequestDTO(links: links)
                )
            )
        }

        if !imageIds.isEmpty {
            let imageResponse = try await adapter.request(
                NoticeRouter.addImage(
                    noticeId: noticeId,
                    body: NoticeImagesRequestDTO(imageIds: imageIds)
                )
            )
            let imageApiResponse = try JSONDecoder().decode(
                APIResponse<NoticeAddImagesResponseDTO>.self,
                from: imageResponse.data
            )
            _ = try imageApiResponse.unwrap()
        }

        // 공지 생성 완료 시점에는 추가 상세 조회를 수행하지 않습니다.
        // 상세 조회는 사용자가 실제 공지 카드를 탭했을 때만 호출합니다.
        let scope: NoticeScope = {
            if body.targetInfo.targetSchoolId != nil {
                return .campus
            }
            if body.targetInfo.targetChapterId != nil {
                return .branch
            }
            return .central
        }()

        let category: NoticeCategory = body.targetInfo.targetParts?.first.map { .part($0) } ?? .general
        let generation = body.targetInfo.targetGisuId > 0 ? String(body.targetInfo.targetGisuId) : "0"

        return NoticeDetail(
            id: noticeId,
            generation: generation,
            scope: scope,
            category: category,
            isMustRead: false,
            title: body.title,
            content: body.content,
            authorID: "",
            authorName: "",
            authorImageURL: nil,
            createdAt: Date(),
            updatedAt: nil,
            targetAudience: TargetAudience(
                generation: generation,
                scope: scope,
                parts: body.targetInfo.targetParts ?? [],
                chapterId: body.targetInfo.targetChapterId.map(String.init),
                schoolId: body.targetInfo.targetSchoolId.map(String.init),
                branches: [],
                schools: []
            ),
            hasPermission: false,
            images: [],
            imageItems: [],
            links: links,
            vote: nil
        )
    }
    
    /// 공지사항 기본 생성 → NoticeItemModel 반환
    public func postNotice(body: PostNoticeRequestDTO) async throws -> NoticeItemModel {
        let response = try await adapter.request(NoticeRouter.postNotice(body: body))
        
        let apiResponse = try JSONDecoder().decode(
            APIResponse<NoticeCreateResponseDTO>.self,
            from: response.data
        )
        let noticeId = try apiResponse.unwrap().noticeId
        let detail = try await getDetailNotice(noticeId: noticeId)
        return detail.toItemModel()
    }
    
    /// 공지사항 투표 추가
    public func addVote(
        noticeId: String,
        body: AddVoteRequestDTO
    ) async throws -> AddVoteResponseDTO {
        let response = try await adapter.request(
            NoticeRouter.addVote(noticeId: noticeId, body: body)
        )

        let apiResponse = try JSONDecoder().decode(
            APIResponse<AddVoteResponseDTO>.self,
            from: response.data
        )
        return try apiResponse.unwrap()
    }
    
    /// 공지사항 링크 추가 → NoticeItemModel 반환
    public func addLink(noticeId: String, links: [String]) async throws -> NoticeItemModel {
        let response = try await adapter.request(
            NoticeRouter.addLink(
                noticeId: noticeId,
                body: NoticeLinksRequestDTO(links: links)
            )
        )
        
        let apiResponse = try JSONDecoder().decode(
            APIResponse<NoticeDTO>.self,
            from: response.data
        )
        let noticeDTO = try apiResponse.unwrap()
        
        return noticeDTO.toItemModel()
    }
    
    /// 공지사항 이미지 추가 → NoticeItemModel 반환
    public func addImage(noticeId: String, imageIds: [String]) async throws -> NoticeItemModel {
        let response = try await adapter.request(
            NoticeRouter.addImage(
                noticeId: noticeId,
                body: NoticeImagesRequestDTO(imageIds: imageIds)
            )
        )
        
        let apiResponse = try JSONDecoder().decode(
            APIResponse<NoticeAddImagesResponseDTO>.self,
            from: response.data
        )
        _ = try apiResponse.unwrap()
        let detail = try await getDetailNotice(noticeId: noticeId)
        return detail.toItemModel()
    }
    
    /// 공지사항 리마인더 발송
    public func sendReminder(noticeId: String, targetIds: [Int]) async throws {
        let response = try await adapter.request(
            NoticeRouter.sendReminder(
                noticeId: noticeId,
                body: NoticeReminderRequestDTO(targetIds: targetIds)
            )
        )
        
        let apiResponse = try JSONDecoder().decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        )
        _ = try apiResponse.unwrap()
    }
    
    /// 공지사항 읽음 처리
    public func readNotice(noticeId: String) async throws {
        let response = try await adapter.request(
            NoticeRouter.readNotice(noticeId: noticeId)
        )
        
        let apiResponse = try JSONDecoder().decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        )
        _ = try apiResponse.unwrap()
    }

    /// 투표 응답(사용자 선택 전송)
    public func submitVoteResponse(noticeId: String, optionIds: [Int]) async throws {
        let response = try await adapter.request(
            NoticeRouter.submitVoteResponse(
                noticeId: noticeId,
                body: NoticeVoteResponseRequestDTO(optionIds: optionIds)
            )
        )

        let apiResponse = try JSONDecoder().decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        )
        _ = try apiResponse.unwrap()
    }

    /// 투표 응답 수정
    public func updateVoteResponse(noticeId: String, optionIds: [Int]) async throws {
        let response = try await adapter.request(
            NoticeRouter.updateVoteResponse(
                noticeId: noticeId,
                body: NoticeVoteResponseRequestDTO(optionIds: optionIds)
            )
        )

        let apiResponse = try JSONDecoder().decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        )
        _ = try apiResponse.unwrap()
    }
    
    // MARK: - 공지 수정
    
    /// 공지사항 수정 (제목, 본문) → NoticeDetail 반환
    public func updateNotice(noticeId: String, body: UpdateNoticeRequestDTO) async throws -> NoticeDetail {
        let response = try await adapter.request(
            NoticeRouter.updateNotice(noticeId: noticeId, body: body)
        )
        
        let apiResponse = try JSONDecoder().decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        )
        _ = try apiResponse.unwrap()
        
        // 수정 후 상세 조회하여 최신 데이터 반환
        return try await getDetailNotice(noticeId: noticeId)
    }
    
    /// 공지사항 링크 수정 → NoticeDetail 반환
    public func updateLinks(noticeId: String, links: [String]) async throws -> NoticeDetail {
        let response = try await adapter.request(
            NoticeRouter.updateLink(
                noticeId: noticeId,
                body: NoticeLinksRequestDTO(links: links)
            )
        )
        
        let apiResponse = try JSONDecoder().decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        )
        _ = try apiResponse.unwrap()
        
        // 수정 후 상세 조회하여 최신 데이터 반환
        return try await getDetailNotice(noticeId: noticeId)
    }
    
    /// 공지사항 이미지 수정 → NoticeDetail 반환
    public func updateImages(noticeId: String, imageIds: [String]) async throws -> NoticeDetail {
        let response = try await adapter.request(
            NoticeRouter.updateImage(
                noticeId: noticeId,
                body: NoticeImagesRequestDTO(imageIds: imageIds)
            )
        )
        
        let apiResponse = try JSONDecoder().decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        )
        _ = try apiResponse.unwrap()
        
        // 수정 후 상세 조회하여 최신 데이터 반환
        return try await getDetailNotice(noticeId: noticeId)
    }
    
    // MARK: - 공지 조회
    
    /// 공지사항 전체 조회
    public func getAllNotices(
        request: NoticeListQuery
    ) async throws -> NoticePageDTO<NoticeDTO> {
        let response = try await adapter.request(
            NoticeRouter.getAllNotices(request: request)
        )

        do {
            let apiResponse = try JSONDecoder().decode(
                APIResponse<NoticePageDTO<NoticeDTO>>.self,
                from: response.data
            )
            let pageDTO = try apiResponse.unwrap()

            #if DEBUG
            print(
                "[NoticeRepository] getAllNotices success " +
                "query=\(request.toParameters) " +
                "contentCount=\(pageDTO.content.count) " +
                "totalElements=\(pageDTO.totalElements)"
            )
            #endif

            return pageDTO
        } catch let decodingError as DecodingError {
            #if DEBUG
            let rawBody = String(data: response.data, encoding: .utf8) ?? "<invalid utf8>"
            print("[NoticeRepository] getAllNotices decodingError=\(decodingError)")
            print("[NoticeRepository] getAllNotices rawBody=\(rawBody)")
            #endif
            throw RepositoryError.decodingError(detail: "Notice list decoding failed: \(decodingError)")
        }
    }
    
    /// 공지사항 상세 조회
    public func getDetailNotice(noticeId: String) async throws -> NoticeDetail {
        let response = try await adapter.request(
            NoticeRouter.getDetailNotice(noticeId: noticeId)
        )

        do {
            let apiResponse = try JSONDecoder().decode(
                APIResponse<NoticeDetailDTO>.self,
                from: response.data
            )
            let detailDTO = try apiResponse.unwrap()

            return detailDTO.toDomain()
        } catch let decodingError as DecodingError {
            #if DEBUG
            let rawBody = String(data: response.data, encoding: .utf8) ?? "<invalid utf8>"
            print("[NoticeRepository] getDetailNotice decodingError=\(decodingError)")
            print("[NoticeRepository] getDetailNotice rawBody=\(rawBody)")
            #endif
            throw RepositoryError.decodingError(detail: "\(decodingError)")
        }
    }
    
    /// 공지 열람 통계 조회
    public func getReadStatics(noticeId: String) async throws -> NoticeReadStaticsDTO {
        let response = try await adapter.request(
            NoticeRouter.getNoticeReadStatusCount(noticeId: noticeId)
        )
        
        let apiResponse = try JSONDecoder().decode(
            APIResponse<NoticeReadStaticsDTO>.self,
            from: response.data
        )
        return try apiResponse.unwrap()
    }
    
    /// 공지 열람 현황 상세 조회
    public func getReadStatusList(
        noticeId: String,
        cursorId: Int = 0,
        filterType: String,
        organizationIds: [Int],
        status: String
    ) async throws -> NoticeReadStatusResponseDTO {
        let response = try await adapter.request(
            NoticeRouter.getNoticeReadStatusList(
                noticeId: noticeId,
                query: NoticeReadStatusListQuery(
                    cursorId: cursorId,
                    filterType: filterType,
                    organizationIds: organizationIds,
                    status: status
                )
            )
        )
        
        let apiResponse = try JSONDecoder().decode(
            APIResponse<NoticeReadStatusResponseDTO>.self,
            from: response.data
        )
        return try apiResponse.unwrap()
    }
    
    /// 공지사항 검색
    public func searchNotice(
        keyword: String,
        request: NoticeListQuery
    ) async throws -> NoticePageDTO<NoticeDTO> {
        let response = try await adapter.request(
            NoticeRouter.searchNotice(keyword: keyword, request: request)
        )
        
        let apiResponse = try JSONDecoder().decode(
            APIResponse<NoticePageDTO<NoticeDTO>>.self,
            from: response.data
        )
        return try apiResponse.unwrap()
    }
    
    // MARK: - 공지 삭제
    
    /// 공지사항 삭제
    public func deleteNotice(noticeId: String) async throws {
        let response = try await adapter.request(
            NoticeRouter.deleteNotice(noticeId: noticeId)
        )
        
        let apiResponse = try JSONDecoder().decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        )
        _ = try apiResponse.unwrap()
    }

    /// 공지사항에 연결된 투표 삭제
    public func deleteVote(noticeId: String) async throws {
        let response = try await adapter.request(
            NoticeRouter.deleteVote(noticeId: noticeId)
        )

        let apiResponse = try JSONDecoder().decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        )
        _ = try apiResponse.unwrap()
    }
}

// MARK: - NoticeDetail → NoticeItemModel 변환

private extension NoticeDetail {
    /// NoticeDetail 도메인 모델을 리스트 표시용 NoticeItemModel로 변환
    func toItemModel() -> NoticeItemModel {
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
            authorNickname: authorNickname,
            authorName: authorName,
            links: links,
            images: images,
            vote: vote,
            viewCount: "0",
            targetsAllGenerations: (Int(targetAudience.generation) ?? 0) <= 0,
            parts: targetAudience.parts,
            isRead: false
        )
    }
}
