//
//  NoticeEditorViewModel+Submit.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import Foundation

extension NoticeEditorViewModel {

    // MARK: - Save

    var hasEditableChanges: Bool {
        hasBaseContentChanges || hasLinkChanges || hasImageChanges || hasVoteChanges
    }

    @MainActor
    func saveNotice() async {
        switch mode {
        case .create:
            await createNewNotice()
        case .edit(let noticeId, _):
            await updateExistingNotice(noticeId: noticeId)
        }
    }

    @MainActor
    func createNewNotice() async {
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

            if shouldSendVoteRequest, let noticeId = Int(notice.id) {
                _ = try await createVote(noticeId: noticeId)
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

    @MainActor
    func updateExistingNotice(noticeId: Int) async {
        createState = .loading

        do {
            var latestNotice: NoticeDetail?
            var didUpdateAnyField = false

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

    @MainActor
    func createVote(noticeId: Int) async throws -> AddVoteResponseDTO {
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

    func buildTargetInfo() -> TargetInfoDTO {
        let currentGeneration = resolvedGisuId > 0 ? resolvedGisuId : 0
        let selectedBranchId = subCategorySelection.selectedBranch?.id
        let selectedSchoolFromSheet = subCategorySelection.selectedSchool?.id
        let selectedParts = subCategorySelection.selectedParts.isEmpty
            ? nil
            : Array(subCategorySelection.selectedParts)

        switch selectedCategory {
        case .all:
            return TargetInfoDTO(
                targetGisuId: 0,
                targetChapterId: nil,
                targetSchoolId: selectedSchoolFromSheet,
                targetParts: nil as [UMCPartType]?
            )
        case .central:
            return TargetInfoDTO(
                targetGisuId: currentGeneration,
                targetChapterId: selectedSchoolFromSheet == nil ? selectedBranchId : nil,
                targetSchoolId: selectedSchoolFromSheet,
                targetParts: selectedParts
            )
        case .branch:
            return TargetInfoDTO(
                targetGisuId: currentGeneration,
                targetChapterId: selectedBranchId,
                targetSchoolId: nil,
                targetParts: selectedParts
            )
        case .school:
            return TargetInfoDTO(
                targetGisuId: currentGeneration,
                targetChapterId: nil,
                targetSchoolId: selectedSchoolFromSheet,
                targetParts: selectedParts
            )
        case .part(let part):
            return TargetInfoDTO(
                targetGisuId: currentGeneration,
                targetChapterId: nil,
                targetSchoolId: nil,
                targetParts: [part]
            )
        }
    }

    func resetForm() {
        title = ""
        content = ""
        noticeImages = []
        noticeLinks = []
        voteFormData = VoteFormData()
        isVoteConfirmed = false
        allowAlert = true
    }

    func sanitizedLinksForRequest() -> [String] {
        noticeLinks
            .map { $0.link.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var hasBaseContentChanges: Bool {
        let currentTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseTitle = originalTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseContent = originalContent.trimmingCharacters(in: .whitespacesAndNewlines)
        return currentTitle != baseTitle || currentContent != baseContent
    }

    var hasLinkChanges: Bool {
        let currentLinks = sanitizedLinksForRequest()
        let baseLinks = originalLinks
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return currentLinks != baseLinks
    }

    var hasImageChanges: Bool {
        let hasPendingNewImages = noticeImages.contains { $0.fileId == nil && $0.imageData != nil }
        if hasPendingNewImages { return true }

        if originalImageIds.isEmpty {
            let currentImageURLs = noticeImages.compactMap(\.imageURL)
            return currentImageURLs != originalImageURLs
        }

        let currentImageIds = noticeImages.compactMap(\.fileId)
        return currentImageIds != originalImageIds
    }

    var hasVoteChanges: Bool {
        currentVoteSnapshot != initialVoteSnapshot
    }

    var currentVoteSnapshot: VoteSnapshot? {
        guard shouldSendVoteRequest else { return nil }
        return makeVoteSnapshot(from: voteFormData)
    }

    func makeVoteSnapshot(from form: VoteFormData) -> VoteSnapshot {
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

    var shouldSendVoteRequest: Bool {
        guard isVoteConfirmed else { return false }

        let title = voteFormData.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !title.isEmpty && sanitizedVoteOptions().count >= 2
    }

    func sanitizedVoteOptions() -> [String] {
        voteFormData.options
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func handleError(_ error: Error, action: String) {
        guard let errorHandler else { return }
        errorHandler.handle(
            error,
            context: ErrorContext(feature: "Notice", action: action)
        )
    }

    @discardableResult
    func presentNoticeServerErrorAlert(for error: RepositoryError) -> Bool {
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

    @discardableResult
    func presentNoticeRequestErrorAlert(for error: NetworkError) -> Bool {
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

    func parseServerMessage(from data: Data?) -> String? {
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

    @MainActor
    func uploadPendingImagesIfNeeded() async throws -> [String] {
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

    @MainActor
    func resolveImageIdsForUpdate(noticeId: Int) async throws -> [String] {
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
    struct VoteSnapshot: Equatable {
        let title: String
        let options: [String]
        let isAnonymous: Bool
        let allowMultipleSelection: Bool
        let startDate: Date
        let endDate: Date
    }
}
