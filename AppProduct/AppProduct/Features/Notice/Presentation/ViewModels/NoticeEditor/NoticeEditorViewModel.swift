//
//  NoticeEditorViewModel.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import Foundation
import SwiftUI
import PhotosUI
import SwiftData
import UIKit

@Observable
final class NoticeEditorViewModel: MultiplePhotoPickerManageable {

    // MARK: - Dependency

    let container: DIContainer
    var modelContext: ModelContext?

    var noticeUseCase: NoticeUseCaseProtocol {
        container.resolve(NoticeUseCaseProtocol.self)
    }

    var targetUseCase: NoticeEditorTargetUseCaseProtocol {
        container.resolve(NoticeEditorTargetUseCaseProtocol.self)
    }

    var genRepository: ChallengerGenRepositoryProtocol {
        container.resolve(ChallengerGenRepositoryProtocol.self)
    }

    var errorHandler: ErrorHandler?

    // MARK: - Mode

    let mode: NoticeEditorMode

    // MARK: - User Context

    var memberId: Int {
        UserDefaults.standard.integer(forKey: AppStorageKey.memberId)
    }

    var gisuId: Int {
        UserDefaults.standard.integer(forKey: AppStorageKey.gisuId)
    }

    var organizationId: Int {
        UserDefaults.standard.integer(forKey: AppStorageKey.organizationId)
    }

    var schoolId: Int {
        UserDefaults.standard.integer(forKey: AppStorageKey.schoolId)
    }

    var organizationType: OrganizationType?
    var memberRole: ManagementTeam?
    var userGisuId: Int?
    var userChapterId: Int?
    var selectedGenerationValue: Int?

    var resolvedGisuId: Int {
        userGisuId ?? gisuId
    }

    var resolvedChapterId: Int {
        userChapterId ?? organizationId
    }

    var selectedGenerationTitle: String? {
        guard let selectedGenerationValue else { return nil }
        return "\(selectedGenerationValue)기"
    }

    // MARK: - View State

    var createState: Loadable<NoticeDetail> = .idle

    var selectedCategory: EditorMainCategory {
        didSet {
            if oldValue != selectedCategory {
                subCategorySelection = EditorSubCategorySelection()
            }
        }
    }

    var subCategorySelection = EditorSubCategorySelection()
    var activeSheetType: TargetSheetType?
    var availableCategories: [EditorMainCategory]
    var branchOptions: [NoticeTargetOption] = []
    var schoolOptions: [NoticeTargetOption] = []
    var targetOptionsState: Loadable<Bool> = .idle
    var title: String = ""
    var content: String = ""
    var editorToolbarViewModel: EditorToolbarViewModel = EditorToolbarViewModel()
    var richAttributedContent: NSAttributedString = NSAttributedString(string: "")
    var showVoting: Bool = false
    var voteFormData: VoteFormData = VoteFormData()
    var isVoteConfirmed: Bool = false
    var alertPrompt: AlertPrompt?
    var selectedPhotoItems: [PhotosPickerItem] = []
    var selectedImages: [UIImage] = []
    var noticeImages: [NoticeImageItem] = []
    var noticeLinks: [NoticeLinkItem] = []
    var allowAlert: Bool = true

    // MARK: - AI State

    var showAIConfirmation: Bool = false
    var isAIProcessing: Bool = false
    var aiStreamingText: String = ""
    var aiTokenUsage: AITokenUsage?
    var aiCumulativeUsedTokens: Int = 0
    var showAICompletionSummary: Bool = false

    // MARK: - Edit Snapshot

    var originalTitle: String = ""
    var originalContent: String = ""
    var originalLinks: [String] = []
    var originalImageIds: [String] = []
    var originalImageURLs: [String] = []
    var originalVoteFormData: VoteFormData?
    var initialVoteSnapshot: VoteSnapshot?

    // MARK: - Derived State

    var isEditMode: Bool {
        if case .edit = mode { return true }
        return false
    }

    var canSubmit: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasRequiredFields = !trimmedTitle.isEmpty && !trimmedContent.isEmpty

        switch mode {
        case .create:
            return hasRequiredFields
        case .edit:
            return hasRequiredFields && hasEditableChanges
        }
    }

    // MARK: - Initializer

    init(
        container: DIContainer,
        mode: NoticeEditorMode = .create,
        selectedGisuId: Int? = nil,
        initialCategory: EditorMainCategory? = nil
    ) {
        self.container = container
        self.mode = mode
        self.userGisuId = selectedGisuId

        let categories: [EditorMainCategory] = [.all, .central]
        availableCategories = categories
        selectedCategory = initialCategory.flatMap { categories.contains($0) ? $0 : nil } ?? categories.first ?? .all

        if case .edit(_, let notice) = mode {
            loadNoticeForEdit(notice)
        }

        refreshSelectedGenerationValue()
    }

    // MARK: - Helper

    func refreshSelectedGenerationValue() {
        let currentGisuId = resolvedGisuId
        guard currentGisuId > 0 else {
            selectedGenerationValue = nil
            return
        }

        do {
            let selectedGeneration = try genRepository
                .fetchGenGisuIdPairs()
                .first(where: { $0.gisuId == currentGisuId })?
                .gen
            selectedGenerationValue = selectedGeneration ?? currentGisuId
        } catch {
            selectedGenerationValue = currentGisuId
        }
    }
}
