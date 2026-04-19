//
//  NoticeEditorViewModel+Targeting.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import Foundation
import UIKit

extension NoticeEditorViewModel {

    // MARK: - Public State

    var visibleSubCategories: [EditorSubCategory] {
        Self.allowedSubCategories(
            for: selectedCategory,
            memberRole: memberRole
        )
    }

    var shouldShowTargetExclusivityHint: Bool {
        visibleSubCategories.contains(.branch) && visibleSubCategories.contains(.school)
    }

    // MARK: - Public Action

    func applyOrganizationType(_ organizationTypeRawValue: String) {
        organizationType = OrganizationType(rawValue: organizationTypeRawValue)
    }

    func applyMemberRole(_ memberRoleRawValue: String) {
        memberRole = ManagementTeam(rawValue: memberRoleRawValue)
        applyEditorPolicyAndReloadTargets()
    }

    func updateUserContext(gisuId: Int, chapterId: Int) {
        userGisuId = gisuId
        userChapterId = chapterId
        refreshSelectedGenerationValue()

        normalizeSelectionForCurrentCategory()
        Task { @MainActor in
            await loadTargetOptions()
        }
    }

    func updateErrorHandler(_ handler: ErrorHandler) {
        errorHandler = handler
    }

    @MainActor
    func loadTargetOptions() async {
        targetOptionsState = .loading

        do {
            switch selectedCategory {
            case .all:
                branchOptions = []
                schoolOptions = try await targetUseCase.fetchAllSchools()
            case .central:
                let canSelectBranch = visibleSubCategories.contains(.branch)
                let canSelectSchool = visibleSubCategories.contains(.school)
                let hasResolvedGisu = resolvedGisuId > 0

                if canSelectBranch, canSelectSchool {
                    async let branches = hasResolvedGisu
                        ? targetUseCase.fetchBranches(gisuId: resolvedGisuId)
                        : targetUseCase.fetchAllBranches()
                    async let schools = hasResolvedGisu
                        ? targetUseCase.fetchSchools(gisuId: resolvedGisuId)
                        : targetUseCase.fetchAllSchools()
                    branchOptions = try await branches
                    schoolOptions = try await schools
                } else if canSelectBranch {
                    branchOptions = try await (
                        hasResolvedGisu
                        ? targetUseCase.fetchBranches(gisuId: resolvedGisuId)
                        : targetUseCase.fetchAllBranches()
                    )
                    schoolOptions = []
                } else if canSelectSchool {
                    branchOptions = []
                    schoolOptions = try await (
                        hasResolvedGisu
                        ? targetUseCase.fetchSchools(gisuId: resolvedGisuId)
                        : targetUseCase.fetchAllSchools()
                    )
                } else {
                    branchOptions = []
                    schoolOptions = []
                }
            case .branch:
                if visibleSubCategories.contains(.branch) {
                    branchOptions = try await (
                        resolvedGisuId > 0
                        ? targetUseCase.fetchBranches(gisuId: resolvedGisuId)
                        : targetUseCase.fetchAllBranches()
                    )
                } else {
                    branchOptions = []
                }
                if visibleSubCategories.contains(.school) {
                    schoolOptions = try await targetUseCase.fetchSchools(
                        inChapterId: resolvedChapterId,
                        gisuId: resolvedGisuId
                    )
                } else {
                    schoolOptions = []
                }
            case .school:
                branchOptions = []
                if visibleSubCategories.contains(.school) {
                    schoolOptions = try await (
                        resolvedGisuId > 0
                        ? targetUseCase.fetchSchools(gisuId: resolvedGisuId)
                        : targetUseCase.fetchAllSchools()
                    )
                } else {
                    schoolOptions = []
                }
            case .part:
                branchOptions = []
                schoolOptions = []
            }
            targetOptionsState = .loaded(true)
        } catch let error as DomainError {
            targetOptionsState = .failed(.domain(error))
            handleError(error, action: "loadTargetOptions")
        } catch let error as NetworkError {
            targetOptionsState = .failed(.network(error))
            handleError(error, action: "loadTargetOptions")
        } catch let error as RepositoryError {
            targetOptionsState = .failed(.repository(error))
            handleError(error, action: "loadTargetOptions")
        } catch {
            targetOptionsState = .failed(.unknown(message: error.localizedDescription))
            handleError(error, action: "loadTargetOptions")
        }

        normalizeSelectionForCurrentCategory()
    }

    func selectCategory(_ category: EditorMainCategory) {
        guard availableCategories.contains(category) else { return }
        selectedCategory = category
        normalizeSelectionForCurrentCategory()
        Task { @MainActor in
            await loadTargetOptions()
        }
    }

    func toggleSubCategory(_ subCategory: EditorSubCategory) {
        guard visibleSubCategories.contains(subCategory) else { return }

        if subCategorySelection.selectedSubCategories.contains(subCategory) {
            subCategorySelection.selectedSubCategories.remove(subCategory)
            clearFilterForSubCategory(subCategory)
        } else {
            subCategorySelection.selectedSubCategories.insert(subCategory)
        }

        normalizeSelectionForCurrentCategory()
    }

    func toggleBranch(_ branch: NoticeTargetOption) {
        guard visibleSubCategories.contains(.branch) else { return }

        if subCategorySelection.selectedBranch == branch {
            subCategorySelection.selectedBranch = nil
            subCategorySelection.selectedSubCategories.remove(.branch)
        } else {
            subCategorySelection.selectedBranch = branch
            subCategorySelection.selectedSchool = nil
            subCategorySelection.selectedSubCategories.remove(.school)
            subCategorySelection.selectedSubCategories.insert(.branch)
        }

        normalizeSelectionForCurrentCategory()
    }

    func toggleSchool(_ school: NoticeTargetOption) {
        guard visibleSubCategories.contains(.school) else { return }

        if subCategorySelection.selectedSchool == school {
            subCategorySelection.selectedSchool = nil
            subCategorySelection.selectedSubCategories.remove(.school)
        } else {
            subCategorySelection.selectedSchool = school
            subCategorySelection.selectedBranch = nil
            subCategorySelection.selectedSubCategories.remove(.branch)
            subCategorySelection.selectedSubCategories.insert(.school)
        }

        normalizeSelectionForCurrentCategory()
    }

    func togglePart(_ part: UMCPartType) {
        guard visibleSubCategories.contains(.part) else { return }

        if subCategorySelection.selectedParts.contains(part) {
            subCategorySelection.selectedParts.remove(part)
        } else {
            subCategorySelection.selectedParts.insert(part)
        }

        if subCategorySelection.selectedParts.isEmpty {
            subCategorySelection.selectedSubCategories.remove(.part)
        } else {
            subCategorySelection.selectedSubCategories.insert(.part)
        }

        normalizeSelectionForCurrentCategory()
    }

    func isSubCategorySelected(_ subCategory: EditorSubCategory) -> Bool {
        subCategorySelection.selectedSubCategories.contains(subCategory)
    }

    func isSubCategoryHighlighted(_ subCategory: EditorSubCategory) -> Bool {
        switch subCategory {
        case .all:
            return false
        case .branch:
            return subCategorySelection.selectedBranch != nil
        case .school:
            return subCategorySelection.selectedSchool != nil
        case .part:
            return !subCategorySelection.selectedParts.isEmpty
        }
    }

    func isBranchSelected(_ branch: NoticeTargetOption) -> Bool {
        subCategorySelection.selectedBranch == branch
    }

    func isSchoolSelected(_ school: NoticeTargetOption) -> Bool {
        subCategorySelection.selectedSchool == school
    }

    func isPartSelected(_ part: UMCPartType) -> Bool {
        subCategorySelection.selectedParts.contains(part)
    }

    func selectSubCategoryIfNeeded(_ subCategory: EditorSubCategory) {
        guard subCategory.hasFilter else { return }
        guard visibleSubCategories.contains(subCategory) else { return }

        if !subCategorySelection.selectedSubCategories.contains(subCategory) {
            subCategorySelection.selectedSubCategories.remove(.all)
            subCategorySelection.selectedSubCategories.insert(subCategory)
        }
        normalizeSelectionForCurrentCategory()
    }

    func openSheet(for subCategory: EditorSubCategory) {
        guard subCategory.hasFilter else { return }
        guard visibleSubCategories.contains(subCategory) else { return }

        Task { @MainActor in
            await loadTargetOptions()
        }

        switch subCategory {
        case .branch:
            activeSheetType = .branch
        case .school:
            activeSheetType = .school
        case .part:
            activeSheetType = .part
        default:
            break
        }
    }

    // MARK: - Edit Bootstrap

    func loadNoticeForEdit(_ notice: NoticeDetail) {
        title = notice.title
        content = notice.content
        richAttributedContent = MarkdownSerializer.deserialize(
            notice.content,
            baseFont: UIFont(name: "Pretendard-Regular", size: 16) ?? UIFont.preferredFont(forTextStyle: .body)
        )
        originalTitle = notice.title
        originalContent = notice.content

        noticeLinks = notice.links.map { NoticeLinkItem(link: $0) }
        originalLinks = notice.links
        let imagesFromMeta = notice.imageItems
            .filter { !$0.id.isEmpty }
            .map {
                NoticeImageItem(
                    imageData: nil,
                    imageURL: $0.url,
                    uploadFileName: nil,
                    isLoading: false,
                    fileId: $0.id
                )
            }
        let imagesFromURLs = notice.images.map {
            NoticeImageItem(
                imageData: nil,
                imageURL: $0,
                uploadFileName: nil,
                isLoading: false,
                fileId: nil
            )
        }

        noticeImages = imagesFromMeta.isEmpty ? imagesFromURLs : imagesFromMeta
        originalImageIds = imagesFromMeta.compactMap(\.fileId)
        originalImageURLs = notice.images

        if let vote = notice.vote {
            let loadedVoteForm = VoteFormData(
                title: vote.question,
                options: vote.options.map { VoteOptionItem(text: $0.title) },
                isAnonymous: vote.isAnonymous,
                allowMultipleSelection: vote.allowMultipleChoices,
                startDate: vote.startDate,
                endDate: vote.endDate
            )
            voteFormData = loadedVoteForm
            isVoteConfirmed = true
            initialVoteSnapshot = makeVoteSnapshot(from: loadedVoteForm)
        } else {
            initialVoteSnapshot = nil
            isVoteConfirmed = false
        }
    }

    // MARK: - Helper

    static func availableCategories(
        for _: OrganizationType?,
        memberRole: ManagementTeam?
    ) -> [EditorMainCategory] {
        _ = memberRole
        return [.all, .central]
    }

    static func availableCategories(for organizationType: OrganizationType?) -> [EditorMainCategory] {
        availableCategories(for: organizationType, memberRole: nil)
    }

    func clearFilterForSubCategory(_ subCategory: EditorSubCategory) {
        switch subCategory {
        case .branch:
            subCategorySelection.selectedBranch = nil
        case .school:
            subCategorySelection.selectedSchool = nil
        case .part:
            subCategorySelection.selectedParts = []
        default:
            break
        }
    }

}

// MARK: - Private Policy
private extension NoticeEditorViewModel {

    static func allowedSubCategories(
        for category: EditorMainCategory,
        memberRole: ManagementTeam?
    ) -> [EditorSubCategory] {
        _ = memberRole
        switch category {
        case .all:
            return [.school]
        case .central:
            return [.branch, .school, .part]
        case .branch:
            return [.all, .part]
        case .school:
            return [.school, .part]
        case .part:
            return []
        }
    }

    func applyEditorPolicyAndReloadTargets() {
        let categories = Self.availableCategories(
            for: organizationType,
            memberRole: memberRole
        )

        if categories != availableCategories {
            availableCategories = categories
        }

        if !availableCategories.contains(selectedCategory) {
            selectedCategory = availableCategories.first ?? .branch
        }

        normalizeSelectionForCurrentCategory()

        Task { @MainActor in
            await loadTargetOptions()
        }
    }

    func normalizeSelectionForCurrentCategory() {
        let allowed = Set(visibleSubCategories)
        subCategorySelection.selectedSubCategories = subCategorySelection
            .selectedSubCategories
            .filter { allowed.contains($0) }

        if !allowed.contains(.branch) {
            subCategorySelection.selectedBranch = nil
        }
        if !allowed.contains(.school) {
            subCategorySelection.selectedSchool = nil
        }
        if !allowed.contains(.part) {
            subCategorySelection.selectedParts = []
        }

        if subCategorySelection.selectedBranch != nil && subCategorySelection.selectedSchool != nil {
            subCategorySelection.selectedSchool = nil
            subCategorySelection.selectedSubCategories.remove(.school)
        }

        if allowed.isEmpty {
            subCategorySelection.selectedSubCategories = []
            subCategorySelection.selectedBranch = nil
            subCategorySelection.selectedSchool = nil
            subCategorySelection.selectedParts = []
        } else if subCategorySelection.selectedSubCategories.contains(.all) {
            subCategorySelection.selectedSubCategories.remove(.all)
        }

        if resolvedGisuId <= 0 && !subCategorySelection.selectedParts.isEmpty {
            subCategorySelection.selectedParts = []
            subCategorySelection.selectedSubCategories.remove(.part)
        }

        if let selectedBranch = subCategorySelection.selectedBranch,
           !branchOptions.contains(selectedBranch) {
            subCategorySelection.selectedBranch = nil
            subCategorySelection.selectedSubCategories.remove(.branch)
        }

        if let selectedSchool = subCategorySelection.selectedSchool,
           !schoolOptions.contains(selectedSchool) {
            subCategorySelection.selectedSchool = nil
            subCategorySelection.selectedSubCategories.remove(.school)
        }
    }
}
