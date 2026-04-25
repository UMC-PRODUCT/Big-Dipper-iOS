//
//  NoticeViewModel+Context.swift
//  AppProduct
//
//  Created by euijjang97 on 2/17/26.
//

import Foundation

extension NoticeViewModel {

    private enum GenerationFilterDefaults {
        static let mainFilter: NoticeMainFilterType = .central
    }

    // MARK: - Context & Filter

    /// 공지 탭 메뉴에 쓰이는 사용자 컨텍스트를 반영합니다.
    ///
    /// - Parameters:
    ///   - schoolName: 사용자 학교명
    ///   - chapterName: 사용자 지부명
    ///   - responsiblePart: 사용자 파트 API 값
    ///   - organizationTypeRawValue: 사용자 조직 타입 raw value
    ///   - chapterId: 사용자 지부 ID
    ///   - schoolId: 사용자 학교 ID
    ///   - memberRoleRawValue: 사용자 역할 raw value
    func applyUserContext(
        schoolName: String,
        chapterName: String,
        responsiblePart: String,
        organizationTypeRawValue: String,
        chapterId: Int,
        schoolId: Int,
        memberRoleRawValue: String,
        generationOrganizationsJSON: String
    ) {
        self.userContext = NoticeUserContext(
            schoolName: schoolName,
            chapterName: chapterName,
            responsiblePart: responsiblePart
        )
        self.organizationType = OrganizationType(rawValue: organizationTypeRawValue)
        self.memberRole = ManagementTeam(rawValue: memberRoleRawValue)
        self.chapterId = chapterId
        self.schoolId = schoolId
        self.generationOrganizations = decodeGenerationOrganizations(from: generationOrganizationsJSON)

        let validMainFilters = mainFilterItems
        let isCurrentPartSelectionValid: Bool = {
            if case .part = selectedMainFilter {
                return canSelectPartFilter
            }
            return validMainFilters.contains(selectedMainFilter)
        }()

        if !isCurrentPartSelectionValid {
            var state = currentState
            state.mainFilter = validMainFilters.first ?? .all
            currentState = state
        }
    }

    private func decodeGenerationOrganizations(from json: String) -> [Int: GenerationOrganizationContext] {
        guard let data = json.data(using: .utf8),
              let contexts = try? JSONDecoder().decode([GenerationOrganizationContext].self, from: data) else {
            return [:]
        }

        return Dictionary(uniqueKeysWithValues: contexts.map { ($0.gen, $0) })
    }

    /// 기수 목록 조회
    func fetchGisuList() {
        guard !isFetchingGisuList else { return }
        isFetchingGisuList = true
        defer { isFetchingGisuList = false }

        do {
            let fetchedPairs = try genRepository.fetchGenGisuIdPairs()
            gisuPairs = fetchedPairs.filter { $0.gisuId > 0 }
            isGisuListLoaded = !gisuPairs.isEmpty

            generations = gisuPairs.map { Generation(value: $0.gen) }

            if let latestGen = generations.max(by: { $0.value < $1.value }) {
                let hasValidSelectedGeneration = generations.contains {
                    $0.value == selectedGeneration.value
                }
                let targetGeneration = hasValidSelectedGeneration ? selectedGeneration : latestGen
                selectedGeneration = targetGeneration

                if generationStates[targetGeneration.value] == nil {
                    generationStates[targetGeneration.value] = GenerationFilterState(
                        mainFilter: GenerationFilterDefaults.mainFilter
                    )
                }

                Task { @MainActor in
                    await refreshSelectedGenerationContext(
                        resetFilters: !hasValidSelectedGeneration
                    )
                }
            } else {
                isGisuListLoaded = false
                noticeItems = .failed(.domain(.custom(message: "기수 정보를 불러오지 못했습니다.")))
                errorHandler.handle(
                    DomainError.custom(message: "기수 정보를 불러오지 못했습니다."),
                    context: .init(
                        feature: "Notice",
                        action: "fetchGisuList"
                    )
                )
            }
        } catch {
            gisuPairs = []
            isGisuListLoaded = false
            generations = []
            noticeItems = .failed(.domain(.custom(message: "기수 정보를 불러오지 못했습니다.")))
            errorHandler.handle(
                error,
                context: .init(
                    feature: "Notice",
                    action: "fetchGisuList"
                )
            )
        }
    }

    /// 기수 선택
    /// - Parameter generation: 선택된 기수
    func selectGeneration(_ generation: Generation) {
        guard gisuPairs.contains(where: { $0.gen == generation.value && $0.gisuId > 0 }) else { return }
        selectedGeneration = generation
        Task { @MainActor in
            await refreshSelectedGenerationContext(resetFilters: true)
        }
    }

    /// 메인필터 선택
    /// - Parameter filter: 선택된 메인 필터
    func selectMainFilter(_ filter: NoticeMainFilterType) {
        var state = currentState
        state.mainFilter = filter
        currentState = state
        isSearchMode = false
        searchQuery = ""
        Task {
            await fetchNotices()
        }
    }

    /// 서브필터 선택
    /// - Parameter subFilter: 선택된 서브 필터
    func selectSubFilter(_ subFilter: NoticeSubFilterType) {
        let key = MainFilterKey(from: selectedMainFilter)
        var mainState = currentState.state(for: key)
        mainState.subFilter = subFilter

        var state = currentState
        state.updateState(for: key, state: mainState)
        currentState = state
        Task {
            await fetchNotices()
        }
    }

    /// 파트 선택
    /// - Parameter part: 선택 파트. `nil`이면 파트 전체 의미
    func selectPart(_ part: NoticePart?) {
        let key = MainFilterKey(from: selectedMainFilter)
        var mainState = currentState.state(for: key)
        mainState.selectedPart = part

        var state = currentState
        state.updateState(for: key, state: mainState)
        currentState = state
        Task {
            await fetchNotices()
        }
    }

    // MARK: - Internal Helper

    /// 현재 선택된 gen에 매핑된 gisuId를 반환
    func currentSelectedGisuId() -> Int? {
        guard isGisuListLoaded else { return nil }
        return gisuPairs.first(where: { $0.gen == selectedGeneration.value && $0.gisuId > 0 })?.gisuId
    }

    /// 선택 기수 기준으로 필터 옵션을 다시 불러오고 목록을 재조회합니다.
    @MainActor
    func refreshSelectedGenerationContext(resetFilters: Bool) async {
        if resetFilters {
            resetSelectionStateForCurrentGeneration()
        } else if generationStates[selectedGeneration.value] == nil {
            generationStates[selectedGeneration.value] = GenerationFilterState(
                mainFilter: GenerationFilterDefaults.mainFilter
            )
        }

        await loadTargetStateForCurrentGeneration()
        await fetchNotices()
    }

    /// 기수 전환 시 필터 선택 상태를 기본값으로 되돌립니다.
    @MainActor
    func resetSelectionStateForCurrentGeneration() {
        generationStates[selectedGeneration.value] = GenerationFilterState(
            mainFilter: GenerationFilterDefaults.mainFilter
        )
        pagingState.reset()
        isSearchMode = false
        searchQuery = ""
    }

    /// 현재 선택 기수의 지부/학교 필터 옵션을 조회합니다.
    @MainActor
    func loadTargetStateForCurrentGeneration() async {
        guard let gisuId = currentSelectedGisuId(), gisuId > 0 else {
            generationTargetStates[selectedGeneration.value] = NoticeGenerationTargetState()
            return
        }

        async let branchesTask = try? noticeEditorTargetUseCase.fetchBranches(gisuId: gisuId)
        async let schoolsTask = try? noticeEditorTargetUseCase.fetchSchools(gisuId: gisuId)

        let branches = await branchesTask ?? []
        let schools = await schoolsTask ?? []

        branches.forEach { chapterNameCache[$0.id] = $0.name }
        generationTargetStates[selectedGeneration.value] = NoticeGenerationTargetState(
            branches: branches,
            schools: schools
        )
    }
}
