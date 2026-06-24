//
//  NoticeViewModel.swift
//  NoticeData
//
//  Created by 이예지 on 5/26/26.
//

import Foundation
import UMCFoundation
import CoreDI
import NoticeDomain

/// 공지사항 리스트 탭 화면 ViewModel
@Observable
final class NoticeViewModel {

    // MARK: - Property

    /// DI Container
    private let container: DIContainer

    /// UseCase (init에서 1회 resolve 후 보관)
    let noticeUseCase: NoticeUseCaseProtocol

    /// 기수 Repository
    let genRepository: ChallengerGenRepositoryProtocol

    /// 읽음 상태 로컬 저장소
    let noticeReadRepository: NoticeReadRepositoryProtocol

    /// 공지 타겟(지부/학교) 조회 UseCase
    let noticeEditorTargetUseCase: NoticeEditorTargetUseCaseProtocol

    /// ViewModel 기능을 extension 파일로 분리해 관리하므로,
    /// 동일 타입 extension에서도 상태 변경이 가능하도록 내부 공개합니다.
    var organizationType: OrganizationType?
    /// 사용자 역할 (역할별 필터/메뉴 가시성 제어에 사용)
    var memberRole: ManagementTeam?
    var chapterId: String = ""
    var schoolId: String = ""
    var generationOrganizations: [String: GenerationOrganizationContext] = [:]

    /// 기수-기수ID 쌍 목록
    var gisuPairs: [(gen: String, gisuId: String)] = []
    /// 지부명 캐시 (chapterId -> chapterName)
    var chapterNameCache: [String: String] = [:]
    /// 기수 매핑 로딩 완료 여부
    var isGisuListLoaded: Bool = false
    /// 기수 매핑 로딩 진행 여부
    var isFetchingGisuList: Bool = false

    var pagingState = NoticePagingState()
    var userContext: NoticeUserContext = .empty

    /// 기수별 필터 상태 저장소
    var generationStates: [String: GenerationFilterState] = [:]
    /// 기수별 지부/학교 필터 옵션 저장소
    var generationTargetStates: [String: NoticeGenerationTargetState] = [:]

    /// 기수 목록
    var generations: [Generation] = []

    /// 선택된 기수
    var selectedGeneration: Generation = Generation(value: "9")

    /// 공지 생성 진입 시 사용할 현재 선택 기수 ID
    var selectedGisuIdForEditor: String? {
        currentSelectedGisuId()
    }

    /// 공지 데이터 (Loadable)
    var noticeItems: Loadable<[NoticeItemModel]> = .idle
    /// 첫 페이지 목록/검색 조회 중복 방지 플래그
    var isFetchingFirstPage: Bool = false

    /// Error Handler
    let errorHandler: ErrorHandler

    /// 페이징 진행 상태 (무한 스크롤 인디케이터 노출용)
    var isLoadingMore: Bool {
        pagingState.isLoadingMore
    }

    /// 검색 관련
    var searchQuery: String = ""
    var isSearchMode: Bool = false

    private enum Pagination {
        static let pageSize: Int = 20
        static let sort: [String] = ["createdAt,DESC"]
    }

    // MARK: - Lifecycle

    /// 의존성을 주입받아 공지 탭 상태를 초기화합니다.
    init(container: DIContainer, errorHandler: ErrorHandler) {
        self.container = container
        self.errorHandler = errorHandler
        self.noticeUseCase = container.resolve(NoticeUseCaseProtocol.self)
        self.genRepository = container.resolve(ChallengerGenRepositoryProtocol.self)
        self.noticeReadRepository = container.resolve(NoticeReadRepositoryProtocol.self)
        self.noticeEditorTargetUseCase = container.resolve(NoticeEditorTargetUseCaseProtocol.self)
    }

    // MARK: - Helper

    /// 현재 기수의 필터 상태
    var currentState: GenerationFilterState {
        get { generationStates[selectedGeneration.value] ?? GenerationFilterState() }
        set { generationStates[selectedGeneration.value] = newValue }
    }

    /// 현재 선택된 메인필터
    var selectedMainFilter: NoticeMainFilterType {
        currentState.mainFilter
    }

    /// 현재 메인필터의 서브필터 상태
    var currentMainFilterState: MainFilterState {
        currentState.state(for: MainFilterKey(from: selectedMainFilter))
    }

    /// 현재 선택된 서브필터
    var selectedSubFilter: NoticeSubFilterType {
        currentMainFilterState.subFilter
    }

    /// 현재 선택된 파트
    var selectedPart: NoticePart? {
        currentMainFilterState.selectedPart
    }

    /// 현재 선택 기수에 매핑된 지부/학교 타겟 옵션
    var currentTargetState: NoticeGenerationTargetState {
        generationTargetStates[selectedGeneration.value] ?? NoticeGenerationTargetState()
    }

    /// 역할(memberRole) 기반으로 노출할 메인필터 항목 목록을 반환합니다.
    ///
    /// 권한과 무관하게 상위 조직 필터는 UMC 공지/본인 지부/본인 학교를 노출합니다.
    /// 파트 필터는 별도 Nested Menu에서 제공합니다.
    var mainFilterItems: [NoticeMainFilterType] {
        [.central, .branch(currentBranchFilterTitle), .school(currentSchoolFilterTitle)]
    }

    /// 상단 메인 메뉴에 표시할 기본 조직 필터 목록(파트 제외)
    var baseMainFilterItems: [NoticeMainFilterType] {
        mainFilterItems.filter {
            if case .part = $0 { return false }
            return true
        }
    }

    /// 파트 Nested Menu 노출 여부
    var canSelectPartFilter: Bool {
        memberRole != .superAdmin
    }

    /// 파트 Nested Menu 항목
    var partFilterItems: [NoticePart] {
        canSelectPartFilter ? NoticePart.allCases : []
    }

    /// 현재 메인필터에 따라 노출할 하단 서브필터 칩 목록을 반환합니다.
    ///
    /// - 전체/파트: 칩 없음
    /// - 중앙/지부: 전체 + 파트
    /// - 학교: 학교 + 파트
    var subFilterChips: [NoticeListSubFilterChip] {
        // iOS 공지 필터는 2계층(기수 + 조직/파트)만 사용합니다.
        []
    }

    /// 서브필터 표시 여부 (중앙/지부/학교만)
    var showSubFilter: Bool {
        false
    }

    var pageSize: Int {
        Pagination.pageSize
    }

    var sort: [String] {
        Pagination.sort
    }

    private var currentBranchFilterTitle: String {
        let resolvedChapterId = selectedGenerationOrganization?.chapterId ?? ""
        return currentTargetState.branches
            .first(where: { $0.id == resolvedChapterId })?
            .name ?? selectedGenerationOrganization?.chapterName ?? NoticeUserContext.empty.branchName
    }

    private var currentSchoolFilterTitle: String {
        let resolvedSchoolId = selectedGenerationOrganization?.schoolId ?? ""
        return currentTargetState.schools
            .first(where: { $0.id == resolvedSchoolId })?
            .name ?? selectedGenerationOrganization?.schoolName ?? NoticeUserContext.empty.schoolName
    }

    var selectedGenerationOrganization: GenerationOrganizationContext? {
        generationOrganizations[selectedGeneration.value]
    }

    var selectedGenerationChapterId: String {
        selectedGenerationOrganization?.chapterId ?? ""
    }

    var selectedGenerationSchoolId: String {
        selectedGenerationOrganization?.schoolId ?? ""
    }

    var currentMemberId: Int {
        AppStorageKey.legacyMemberIdInt()
    }
}
