//
//  NoticeUseCase.swift
//  AppProduct
//
//  Created by 이예지 on 2/14/26.
//

import Foundation

/// 공지사항 비즈니스 로직 구현체
///
/// 입력 검증, 이미지 업로드(Presigned URL 3단계), 공지 CRUD를 처리합니다.
final class NoticeUseCase: NoticeUseCaseProtocol {
    
    // MARK: - Property
    private let repository: NoticeRepositoryProtocol
    private let storageRepository: StorageRepositoryProtocol
    
    // MARK: - Initializer
    init(
        repository: NoticeRepositoryProtocol,
        storageRepository: StorageRepositoryProtocol
    ) {
        self.repository = repository
        self.storageRepository = storageRepository
    }
    
    // MARK: - NoticeUseCaseProtocol
    
    // MARK: 파일 업로드
    
    /// Presigned URL 방식으로 공지 첨부 이미지를 업로드합니다.
    ///
    /// 1. `prepareUpload`로 업로드 URL 발급
    /// 2. `uploadFile`로 S3에 바이너리 전송
    /// 3. `confirmUpload`로 서버에 완료 통보
    ///
    /// - Parameters:
    ///   - imageData: 업로드할 JPEG 바이너리 데이터
    ///   - fileName: 업로드 파일명 (앨범 원본 이름 기반)
    /// - Returns: 저장된 파일 ID
    func uploadNoticeAttachmentImage(imageData: Data, fileName: String?) async throws -> String {
        guard !imageData.isEmpty else {
            throw DomainError.custom(message: "이미지 데이터가 비어있습니다")
        }
        
        let resolvedFileName = {
            guard let fileName,
                  !fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return "notice_\(UUID().uuidString).jpg"
            }
            return fileName
        }()
        let contentType = "image/jpeg"
        
        let prepared = try await storageRepository.prepareUpload(
            fileName: resolvedFileName,
            contentType: contentType,
            fileSize: imageData.count,
            category: .noticeAttachment
        )
        
        try await storageRepository.uploadFile(
            to: prepared.uploadUrl,
            data: imageData,
            method: prepared.uploadMethod,
            headers: prepared.headers,
            contentType: contentType
        )
        
        try await storageRepository.confirmUpload(fileId: prepared.fileId)
        return prepared.fileId
    }
    
    // MARK: 공지 생성 (POST)
    /// 공지 생성
    func createNotice(
        title: String,
        content: String,
        shouldNotify: Bool,
        targetInfo: TargetInfoDTO,
        links: [String] = [],
        imageIds: [String] = [],
        noticeTab: String,
        mustRead: Bool
    ) async throws -> NoticeDetail {
        guard !title.isEmpty else {
            throw DomainError.custom(message: "제목을 입력해주세요")
        }

        guard !content.isEmpty else {
            throw DomainError.custom(message: "내용을 입력해주세요")
        }

        let resolvedTargetInfo = TargetInfoDTO(
            targetGisuId: targetInfo.targetGisuId,
            targetChapterId: targetInfo.targetChapterId,
            targetSchoolId: targetInfo.targetSchoolId,
            targetParts: targetInfo.targetParts,
            targetNoticeTab: noticeTab
        )

        let requestDTO = PostNoticeRequestDTO(
            title: title,
            content: content,
            shouldNotify: shouldNotify,
            targetInfo: resolvedTargetInfo,
            mustRead: mustRead
        )
        return try await repository.createNotice(
            body: requestDTO,
            links: links,
            imageIds: imageIds
        )
    }
    
    /// 공지사항 투표 추가
    func addVote(
        noticeId: Int,
        title: String,
        isAnonymous: Bool,
        allowMultipleChoice: Bool,
        startsAt: Date,
        endsAtExclusive: Date,
        options: [String]
    ) async throws -> AddVoteResponseDTO {
        // 1. Validation
        guard !title.isEmpty else {
            throw DomainError.custom(message: "투표 제목을 입력해주세요")
        }

        guard options.count >= 2 else {
            throw DomainError.custom(message: "투표 옵션은 최소 2개 이상이어야 합니다")
        }

        guard startsAt < endsAtExclusive else {
            throw DomainError.custom(message: "종료 시간은 시작 시간보다 늦어야 합니다")
        }

        // 2. Date → ISO8601 UTC String 변환
        let startsAtString = ServerDateTimeConverter.toUTCDateTimeString(startsAt)
        let endsAtString = ServerDateTimeConverter.toUTCDateTimeString(endsAtExclusive)

        // 3. DTO 생성
        let requestDTO = AddVoteRequestDTO(
            title: title,
            isAnonymous: isAnonymous,
            allowMultipleChoice: allowMultipleChoice,
            startsAt: startsAtString,
            endsAtExclusive: endsAtString,
            options: options
        )

        // 4. Repository 호출
        return try await repository.addVote(noticeId: noticeId, body: requestDTO)
    }
    
    /// 공지사항 링크 추가
    func addLink(noticeId: Int, links: [String]) async throws -> NoticeItemModel {
        guard !links.isEmpty else {
            throw DomainError.custom(message: "추가할 링크를 입력해주세요")
        }
        for link in links {
            guard URL(string: link) != nil else {
                throw DomainError.custom(message: "올바른 URL 형식이 아닙니다: \(link)")
            }
        }
        return try await repository.addLink(noticeId: noticeId, links: links)
    }
    
    /// 공지사항 이미지 추가
    func addImage(noticeId: Int, imageIds: [String]) async throws -> NoticeItemModel {
        guard !imageIds.isEmpty else {
            throw DomainError.custom(message: "추가할 이미지를 선택해주세요")
        }
        return try await repository.addImage(noticeId: noticeId, imageIds: imageIds)
    }
    
    /// 공지 읽음 처리
    func readNotice(noticeId: Int) async throws {
        try await repository.readNotice(noticeId: noticeId)
    }

    /// 투표 응답(사용자 선택 전송)
    func submitVoteResponse(noticeId: Int, optionIds: [Int]) async throws {
        guard noticeId > 0 else {
            throw DomainError.custom(message: "유효하지 않은 공지입니다")
        }
        guard !optionIds.isEmpty else {
            throw DomainError.custom(message: "선택한 항목이 없습니다")
        }
        try await repository.submitVoteResponse(noticeId: noticeId, optionIds: optionIds)
    }

    /// 투표 응답 수정 (빈 배열 전송 시 투표 해제)
    func updateVoteResponse(noticeId: Int, optionIds: [Int]) async throws {
        guard noticeId > 0 else {
            throw DomainError.custom(message: "유효하지 않은 공지입니다")
        }
        try await repository.updateVoteResponse(noticeId: noticeId, optionIds: optionIds)
    }
    
    /// 미확인 대상에게 공지 리마인더 발송
    func sendReminder(noticeId: Int, targetIds: [Int]) async throws {
        guard !targetIds.isEmpty else {
            throw DomainError.custom(message: "리마인더를 받을 대상을 선택해주세요")
        }
        try await repository.sendReminder(noticeId: noticeId, targetIds: targetIds)
    }
    
    // MARK: 공지 수정 (PATCH)
    
    /// 공지사항 수정 (제목, 본문)
    func updateNotice(
        noticeId: Int,
        title: String,
        content: String,
        mustRead: Bool
    ) async throws -> NoticeDetail {
        guard !title.isEmpty else {
            throw DomainError.custom(message: "제목을 입력해주세요")
        }

        guard !content.isEmpty else {
            throw DomainError.custom(message: "내용을 입력해주세요")
        }

        let requestDTO = UpdateNoticeRequestDTO(
            title: title,
            content: content,
            mustRead: mustRead
        )
        return try await repository.updateNotice(noticeId: noticeId, body: requestDTO)
    }
    
    /// 공지사항 링크 수정 (빈 배열 전달 시 전체 삭제)
    func updateLinks(
        noticeId: Int,
        links: [String]
    ) async throws -> NoticeDetail {
        // 빈 배열 허용 (링크 전체 삭제 가능)
        for link in links {
            guard URL(string: link) != nil else {
                throw DomainError.custom(message: "올바른 URL 형식이 아닙니다: \(link)")
            }
        }
        return try await repository.updateLinks(noticeId: noticeId, links: links)
    }
    
    /// 공지사항 이미지 수정 (빈 배열 전달 시 전체 삭제)
    func updateImages(
        noticeId: Int,
        imageIds: [String]
    ) async throws -> NoticeDetail {
        // 빈 배열 허용 (이미지 전체 삭제 가능)
        return try await repository.updateImages(noticeId: noticeId, imageIds: imageIds)
    }
    
    // MARK: 공지 조회 (GET)
    
    /// 공지사항 전체 조회
    func getAllNotices(
        request: NoticeListRequestDTO
    ) async throws -> NoticePageDTO<NoticeDTO> {
        guard request.gisuId > 0 else {
            throw DomainError.custom(message: "기수를 선택해주세요")
        }
        
        return try await repository.getAllNotices(request: request)
    }
    
    /// 공지사항 상세 조회
    func getDetailNotice(noticeId: Int) async throws -> NoticeDetail {
        return try await repository.getDetailNotice(noticeId: noticeId)
    }
    
    /// 공지 열람 통계 조회
    func getReadStatics(noticeId: Int) async throws -> NoticeReadStaticsDTO {
        return try await repository.getReadStatics(noticeId: noticeId)
    }
    
    /// 공지 열람 현황 상세 조회
    func getReadStatusList(
        noticeId: Int,
        cursorId: Int = 0,
        filterType: String,
        organizationIds: [Int] = [],
        status: String
    ) async throws -> NoticeReadStatusResponseDTO {
        return try await repository.getReadStatusList(
            noticeId: noticeId,
            cursorId: cursorId,
            filterType: filterType,
            organizationIds: organizationIds,
            status: status
        )
    }
    
    /// 공지사항 검색
    func searchNotice(
        keyword: String,
        request: NoticeListRequestDTO
    ) async throws -> NoticePageDTO<NoticeDTO> {
        guard !keyword.isEmpty else {
            throw DomainError.custom(message: "검색어를 입력해주세요")
        }
        
        guard request.gisuId > 0 else {
            throw DomainError.custom(message: "기수를 선택해주세요")
        }
        
        return try await repository.searchNotice(keyword: keyword, request: request)
    }
    
    // MARK: 공지 삭제 (DELETE)
    
    /// 공지사항 삭제
    func deleteNotice(noticeId: Int) async throws {
        try await repository.deleteNotice(noticeId: noticeId)
    }

    /// 공지사항에 연결된 투표 삭제
    func deleteVote(noticeId: Int) async throws {
        try await repository.deleteVote(noticeId: noticeId)
    }
}
