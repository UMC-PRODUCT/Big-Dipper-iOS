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

    /// 현재 권한 기준으로 노출 가능한 서브카테고리 목록입니다.
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

    /// 조직 타입 기준으로 메인 카테고리 목록을 갱신합니다.
    func applyOrganizationType(_ organizationTypeRawValue: String) {
        organizationType = OrganizationType(rawValue: organizationTypeRawValue)
        // 메뉴/권한 정책은 memberRole 기준으로만 관리합니다.
    }

    /// 멤버 역할 기준으로 메인 카테고리/서브카테고리 정책을 갱신합니다.
    func applyMemberRole(_ memberRoleRawValue: String) {
        memberRole = ManagementTeam(rawValue: memberRoleRawValue)
        applyEditorPolicyAndReloadTargets()
    }

    /// 뷰에서 사용자 컨텍스트(AppStorage)를 전달받아 반영합니다.
    func updateUserContext(gisuId: Int, chapterId: Int) {
        userGisuId = gisuId
        userChapterId = chapterId
        refreshSelectedGenerationValue()

        normalizeSelectionForCurrentCategory()
        Task { @MainActor in
            await loadTargetOptions()
        }
    }

    /// View 계층의 ErrorHandler를 바인딩합니다.
    func updateErrorHandler(_ handler: ErrorHandler) {
        errorHandler = handler
    }

    /// 현재 메인 카테고리에 맞는 타겟 목록을 조회합니다.
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

    /// 메인 카테고리를 선택하고 해당 타겟 옵션을 로드합니다.
    func selectCategory(_ category: EditorMainCategory) {
        guard availableCategories.contains(category) else { return }
        selectedCategory = category
        normalizeSelectionForCurrentCategory()
        Task { @MainActor in
            await loadTargetOptions()
        }
    }

    /// 서브카테고리 토글
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

    /// 지부 선택 토글
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

    /// 학교 선택 토글
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

    /// 파트 선택 토글
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

    /// 게시판 분류 칩의 시각적 선택 상태를 반환합니다.
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

    /// 필터형 서브카테고리(지부/학교/파트)를 탭했을 때 선택 상태를 보장합니다.
    func selectSubCategoryIfNeeded(_ subCategory: EditorSubCategory) {
        guard subCategory.hasFilter else { return }
        guard visibleSubCategories.contains(subCategory) else { return }

        if !subCategorySelection.selectedSubCategories.contains(subCategory) {
            subCategorySelection.selectedSubCategories.remove(.all)
            subCategorySelection.selectedSubCategories.insert(subCategory)
        }
        normalizeSelectionForCurrentCategory()
    }

    /// 서브카테고리에 맞는 타겟 선택 시트를 엽니다.
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

    /// 수정할 공지 데이터를 에디터 상태로 로드합니다.
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

    /// 조직 타입/역할에 따라 사용 가능한 메인 카테고리 목록을 반환합니다.
    static func availableCategories(
        for _: OrganizationType?,
        memberRole: ManagementTeam?
    ) -> [EditorMainCategory] {
        _ = memberRole
        return [.all, .central]
    }

    /// 레거시 시그니처 유지용 래퍼입니다.
    static func availableCategories(for organizationType: OrganizationType?) -> [EditorMainCategory] {
        availableCategories(for: organizationType, memberRole: nil)
    }

    /// 해당 서브카테고리의 필터 선택 상태를 초기화합니다.
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

    /// 메인 카테고리와 역할 조합에 따라 노출 가능한 서브카테고리를 반환합니다.
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

    /// 역할 변경 시 에디터 정책(카테고리/서브카테고리)을 재적용하고 타겟 옵션을 다시 로드합니다.
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

    /// 현재 카테고리에 맞지 않는 서브카테고리 선택을 정리하고 일관된 상태로 보정합니다.
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

        // 지부/학교 동시 지정 방지
        if subCategorySelection.selectedBranch != nil && subCategorySelection.selectedSchool != nil {
            subCategorySelection.selectedSchool = nil
            subCategorySelection.selectedSubCategories.remove(.school)
        }

        // 더 이상 숨겨진 "전체" 기본값을 사용하지 않습니다.
        if allowed.isEmpty {
            subCategorySelection.selectedSubCategories = []
            subCategorySelection.selectedBranch = nil
            subCategorySelection.selectedSchool = nil
            subCategorySelection.selectedParts = []
        } else if subCategorySelection.selectedSubCategories.contains(.all) {
            subCategorySelection.selectedSubCategories.remove(.all)
        }

        // 기수 미선택 시 금지 조합 방지
        if resolvedGisuId <= 0 && !subCategorySelection.selectedParts.isEmpty {
            subCategorySelection.selectedParts = []
            subCategorySelection.selectedSubCategories.remove(.part)
        }

        // 옵션 목록에서 제거된 항목 정리
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
