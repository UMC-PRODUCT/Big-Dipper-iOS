//
//  NoticeEditorViewModel+Submit.swift
//  NoticeData
//
//  Created by 이예지 on 6/1/26.
//

import Foundation
import UMCFoundation
import NoticeDomain

extension NoticeEditorViewModel {

    // MARK: - Save

    /// 수정 화면에서 실제 편집 가능한 값이 변경되었는지 반환합니다.
    public var hasEditableChanges: Bool {
        hasBaseContentChanges || hasLinkChanges || hasImageChanges || hasVoteChanges
    }

    /// 공지사항 저장 (생성 or 수정)
    @MainActor
    public func saveNotice() async {
        switch mode {
        case .create:
            await createNewNotice()
        case .edit(let noticeId, _):
            await updateExistingNotice(noticeId: noticeId)
        }
    }

    /// 새 공지사항을 생성합니다.
    ///
    /// 이미지 업로드 -> 공지 생성 -> 투표 첨부(선택) 순서로 진행됩니다.
    @MainActor
    public func createNewNotice() async {
        createState = .loading

        do {
            let imageIds = try await uploadPendingImagesIfNeeded()
            let targetInfo = buildTargetInfo()
            let links = sanitizedLinksForRequest()

            let notice = try await noticeUseCase.createNotice(
                title: title,
                content: content,
                shouldNotify: allowAlert,
                targetInfo: targetInfo,
                links: links,
                imageIds: imageIds
            )

            if shouldSendVoteRequest {
                  _ = try await createVote(noticeId: notice.id)
              }

            createState = .loaded(notice)
            resetForm()
        } catch let error as DomainError {
            createState = .failed(.domain(error))
            handleError(error, action: "createNotice")
        } catch let error as RepositoryError {
            createState = .failed(.repository(error))
            if !presentNoticeServerErrorAlert(for: error) {
                handleError(error, action: "createNotice")
            }
        } catch let error as NetworkError {
            createState = .failed(.network(error))
            if !presentNoticeRequestErrorAlert(for: error) {
                handleError(error, action: "createNotice")
            }
        } catch {
            createState = .failed(.unknown(message: error.localizedDescription))
            handleError(error, action: "createNotice")
        }
    }

    /// 기존 공지사항을 수정합니다.
    ///
    /// 변경된 필드(제목/내용, 링크, 이미지, 투표)만 선별적으로 API를 호출합니다.
    @MainActor
    public func updateExistingNotice(noticeId: String) async {
        createState = .loading

        do {
            var latestNotice: NoticeDetail?
            var didUpdateAnyField = false

            // 변경 감지된 필드만 개별 API 호출
            if hasBaseContentChanges {
                latestNotice = try await noticeUseCase.updateNotice(
                    noticeId: noticeId,
                    title: title,
                    content: content
                )
                didUpdateAnyField = true
            }

            if hasLinkChanges {
                let links = sanitizedLinksForRequest()
                latestNotice = try await noticeUseCase.updateLinks(
                    noticeId: noticeId,
                    links: links
                )
                didUpdateAnyField = true
            }

            if hasImageChanges {
                _ = try await uploadPendingImagesIfNeeded()
                let imageIds = try await resolveImageIdsForUpdate(noticeId: noticeId)
                latestNotice = try await noticeUseCase.updateImages(
                    noticeId: noticeId,
                    imageIds: imageIds
                )
                didUpdateAnyField = true
            }

            if hasVoteChanges {
                if initialVoteSnapshot != nil {
                    try await noticeUseCase.deleteVote(noticeId: noticeId)
                    didUpdateAnyField = true
                }

                if shouldSendVoteRequest {
                    _ = try await createVote(noticeId: noticeId)
                    didUpdateAnyField = true
                }

                latestNotice = try await noticeUseCase.getDetailNotice(noticeId: noticeId)
            }

            guard didUpdateAnyField else {
                createState = .loaded(
                    try await noticeUseCase.getDetailNotice(noticeId: noticeId)
                )
                return
            }

            if let latestNotice {
                createState = .loaded(latestNotice)
            } else {
                createState = .loaded(
                    try await noticeUseCase.getDetailNotice(noticeId: noticeId)
                )
            }
        } catch let error as DomainError {
            createState = .failed(.domain(error))
            handleError(error, action: "updateNotice")
        } catch let error as RepositoryError {
            createState = .failed(.repository(error))
            if !presentNoticeServerErrorAlert(for: error) {
                handleError(error, action: "updateNotice")
            }
        } catch let error as NetworkError {
            createState = .failed(.network(error))
            if !presentNoticeRequestErrorAlert(for: error) {
                handleError(error, action: "updateNotice")
            }
        } catch {
            createState = .failed(.unknown(message: error.localizedDescription))
            handleError(error, action: "updateNotice")
        }
    }

    /// 공지에 투표를 생성합니다.
    @discardableResult
    public func createVote(noticeId: String) async throws -> String {
        let options = sanitizedVoteOptions()
        let title = voteFormData.title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return try await noticeUseCase.addVote(
            noticeId: noticeId,
            title: title,
            isAnonymous: voteFormData.isAnonymous,
            allowMultipleChoice: voteFormData.allowMultipleSelection,
            startsAt: voteFormData.startDate,
            endsAtExclusive: voteFormData.endDate,
            options: options
        )
    }

    /// 공지 생성 API용 TargetInfoDTO를 구성합니다.
    public func buildTargetInfo() -> NoticeTargetInfo {
        let currentGeneration = resolvedGisuId > 0 ? resolvedGisuId : 0
        let selectedBranchId = subCategorySelection.selectedBranch?.id
        let selectedSchoolFromSheet = subCategorySelection.selectedSchool?.id
        let selectedParts = subCategorySelection.selectedParts.isEmpty
            ? nil
            : Array(subCategorySelection.selectedParts)

        switch selectedCategory {
        case .all:
            return NoticeTargetInfo(
                gisuId: "0",
                chapterId: nil,
                schoolId: selectedSchoolFromSheet,
                parts: nil,
                noticeTab: nil
            )
        case .central:
            return NoticeTargetInfo(
                gisuId: String(currentGeneration),
                chapterId: selectedSchoolFromSheet == nil ? selectedBranchId : nil,
                schoolId: selectedSchoolFromSheet,
                parts: selectedParts,
                noticeTab: nil
            )
        case .branch:
            let resolvedChapterId: String? = if memberRole?.canWriteChallengerChapterNotice == true,
                                             selectedBranchId == nil,
                                             let chapterId = userChapterId, chapterId > 0 {
                String(chapterId)
            } else {
                selectedBranchId
            }
            return NoticeTargetInfo(
                gisuId: String(currentGeneration),
                chapterId: resolvedChapterId,
                schoolId: nil,
                parts: selectedParts,
                noticeTab: nil
            )
        case .school:
            return NoticeTargetInfo(
                gisuId: String(currentGeneration),
                chapterId: nil,
                schoolId: selectedSchoolFromSheet,
                parts: selectedParts,
                noticeTab: nil
            )
        case .part(let part):
            return NoticeTargetInfo(
                gisuId: String(currentGeneration),
                chapterId: nil,
                schoolId: nil,
                parts: [part],
                noticeTab: nil
            )
        case .management(let scenario):
            let managementParts = subCategorySelection.selectedParts.isEmpty
                ? nil
                : Array(subCategorySelection.selectedParts)
            // 서버 스펙: 운영진 공지는 기수 필수. 작성자의 현재 기수를 사용.
            switch scenario {
            case .centralAll:
                return NoticeTargetInfo(
                    gisuId: String(currentGeneration),
                    chapterId: nil,
                    schoolId: nil,
                    parts: nil,
                    noticeTab: StaffNoticeTab.centralMember.rawValue
                )
            case .schoolCore:
                let schoolCoreSchoolId: String? = (memberRole?.bindsOwnSchoolForSchoolCoreNotice ?? false)
                    ? (schoolId > 0 ? String(schoolId) : nil)
                    : nil
                return NoticeTargetInfo(
                    gisuId: String(currentGeneration),
                    chapterId: nil,
                    schoolId: schoolCoreSchoolId,
                    parts: nil,
                    noticeTab: StaffNoticeTab.schoolCore.rawValue
                )
            case .schoolPartLeader:
                let partLeaderSchoolId: String? = (memberRole?.bindsOwnSchoolForPartLeaderNotice ?? false)
                    ? (schoolId > 0 ? String(schoolId) : nil)
                    : nil
                return NoticeTargetInfo(
                    gisuId: String(currentGeneration),
                    chapterId: nil,
                    schoolId: partLeaderSchoolId,
                    parts: managementParts,
                    noticeTab: StaffNoticeTab.schoolPartLeader.rawValue
                )
            }
        }
    }

    /// 에디터 폼 상태를 초기값으로 리셋합니다.
    public func resetForm() {
        title = ""
        content = ""
        noticeImages = []
        noticeLinks = []
        voteFormData = VoteFormData()
        isVoteConfirmed = false
        allowAlert = true
    }

    /// 링크 첨부 카드에서 입력된 값 중 실제 전송 가능한 링크만 추출합니다.
    public func sanitizedLinksForRequest() -> [String] {
        noticeLinks
            .map { $0.link.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// 제목/내용 변경 여부
    public var hasBaseContentChanges: Bool {
        let currentTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseTitle = originalTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseContent = originalContent.trimmingCharacters(in: .whitespacesAndNewlines)
        return currentTitle != baseTitle || currentContent != baseContent
    }

    /// 링크 전체 교체 변경 여부
    public var hasLinkChanges: Bool {
        let currentLinks = sanitizedLinksForRequest()
        let baseLinks = originalLinks
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return currentLinks != baseLinks
    }

    /// 이미지 전체 교체 변경 여부
    public var hasImageChanges: Bool {
        let hasPendingNewImages = noticeImages.contains { $0.fileId == nil && $0.imageData != nil }
        if hasPendingNewImages { return true }

        // imageId가 없는 응답 케이스는 URL 기준으로 변경 감지
        if originalImageIds.isEmpty {
            let currentImageURLs = noticeImages.compactMap(\.imageURL)
            return currentImageURLs != originalImageURLs
        }

        let currentImageIds = noticeImages.compactMap(\.fileId)
        return currentImageIds != originalImageIds
    }

    /// 투표 변경 여부
    public var hasVoteChanges: Bool {
        currentVoteSnapshot != initialVoteSnapshot
    }

    /// 현재 화면 상태에서 전송 가능한 투표 스냅샷
    public var currentVoteSnapshot: VoteSnapshot? {
        guard shouldSendVoteRequest else { return nil }
        return makeVoteSnapshot(from: voteFormData)
    }

    /// 투표 폼 데이터로 비교 가능한 스냅샷을 생성합니다.
    public func makeVoteSnapshot(from form: VoteFormData) -> VoteSnapshot {
        VoteSnapshot(
            title: form.title.trimmingCharacters(in: .whitespacesAndNewlines),
            options: form.options
                .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty },
            isAnonymous: form.isAnonymous,
            allowMultipleSelection: form.allowMultipleSelection,
            startDate: form.startDate,
            endDate: form.endDate
        )
    }

    /// 투표 요청 전송 여부를 판단합니다.
    public var shouldSendVoteRequest: Bool {
        guard isVoteConfirmed else { return false }

        let title = voteFormData.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !title.isEmpty && sanitizedVoteOptions().count >= 2
    }

    /// 투표 옵션 입력값 중 실제 전송 가능한 옵션만 추출합니다.
    public func sanitizedVoteOptions() -> [String] {
        voteFormData.options
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// 저장 실패를 전역 ErrorHandler로 전달합니다.
    public func handleError(_ error: Error, action: String) {
        guard let errorHandler else { return }
        errorHandler.handle(
            error,
            context: ErrorContext(feature: "Notice", action: action)
        )
    }

    /// 공지 작성/수정 관련 서버 에러를 즉시 Alert로 표시합니다.
    ///
    /// 서버가 내려준 NOTICE 계열 메시지는 작성 화면에서 바로 노출해
    /// 사용자가 저장 실패 원인을 즉시 이해할 수 있도록 합니다.
    @discardableResult
    public func presentNoticeServerErrorAlert(for error: RepositoryError) -> Bool {
        guard case let .serverError(code, message) = error else {
            return false
        }

        guard let code, code.hasPrefix("NOTICE-") else {
            return false
        }

        alertPrompt = AlertPrompt(
            title: "공지 저장 실패",
            message: message ?? error.userMessage,
            positiveBtnTitle: "확인"
        )
        return true
    }

    /// 권한 오류 등 HTTP 실패 응답의 서버 메시지를 작성 화면 Alert로 표시합니다.
    @discardableResult
    public func presentNoticeRequestErrorAlert(for error: NetworkError) -> Bool {
        guard case let .requestFailed(statusCode, data) = error else {
            return false
        }

        guard let serverMessage = parseServerMessage(from: data) else {
            return false
        }

        let alertTitle = statusCode == 403 ? "권한 없음" : "공지 저장 실패"
        alertPrompt = AlertPrompt(
            title: alertTitle,
            message: serverMessage,
            positiveBtnTitle: "확인"
        )
        return true
    }

    public func parseServerMessage(from data: Data?) -> String? {
        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        if let message = (json["message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !message.isEmpty {
            return message
        }

        if let result = (json["result"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !result.isEmpty {
            return result
        }

        return nil
    }

    /// 저장 시점에만 파일 업로드 플로우를 실행하고 fileId 배열을 반환합니다.
    @MainActor
    public func uploadPendingImagesIfNeeded() async throws -> [String] {
        for index in noticeImages.indices {
            guard noticeImages[index].fileId == nil,
                  let imageData = noticeImages[index].imageData else { continue }

            noticeImages[index].isLoading = true
            do {
                noticeImages[index].fileId = try await noticeUseCase.uploadNoticeAttachmentImage(
                    imageData: imageData,
                    fileName: noticeImages[index].uploadFileName
                )
                noticeImages[index].isLoading = false
            } catch {
                noticeImages[index].isLoading = false
                throw error
            }
        }

        return noticeImages.compactMap { $0.fileId }
    }

    /// 수정 이미지 교체 API에 전달할 imageId 목록을 구성합니다.
    ///
    /// - fileId가 있는 항목은 그대로 사용
    /// - fileId가 없는 기존 원격 이미지(URL)는 상세 재조회 후 URL→ID 매핑으로 보완
    @MainActor
    public func resolveImageIdsForUpdate(noticeId: String) async throws -> [String] {
        let hasUnresolvedRemoteImage = noticeImages.contains {
            $0.fileId == nil && $0.imageData == nil && ($0.imageURL?.isEmpty == false)
        }

        var urlToId: [String: String] = [:]
        if hasUnresolvedRemoteImage {
            let latestDetail = try await noticeUseCase.getDetailNotice(noticeId: noticeId)
            urlToId = Dictionary(
                uniqueKeysWithValues: latestDetail.imageItems.map { ($0.url, $0.id) }
            )
        }

        return noticeImages.compactMap { item in
            if let fileId = item.fileId, !fileId.isEmpty {
                return fileId
            }
            if let imageURL = item.imageURL {
                return urlToId[imageURL]
            }
            return nil
        }
    }
}

extension NoticeEditorViewModel {
    /// 투표 폼의 비교 가능한 스냅샷 (수정 변경 감지용)
    public struct VoteSnapshot: Equatable {
        let title: String
        let options: [String]
        let isAnonymous: Bool
        let allowMultipleSelection: Bool
        let startDate: Date
        let endDate: Date
    }
}
