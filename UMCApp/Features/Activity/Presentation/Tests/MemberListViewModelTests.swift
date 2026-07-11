//
//  MemberListViewModelTests.swift
//  ActivityPresentationTests
//
//  Created by jaewon Lee on 6/28/26.
//

import Foundation
import Testing
import ActivityDomain
import UMCFoundation
@testable import ActivityPresentation

#if DEBUG

// MARK: - Helpers

/// 멤버 픽스처. `memberID`/`challengerID` 외 필드는 테스트 결과와 무관한 고정값입니다.
private func makeMember(
    memberID: String?,
    challengerID: String? = nil,
    name: String = "홍길동",
    part: UMCPartType = .front(type: .ios)
) -> MemberManagementItem {
    MemberManagementItem(
        memberID: memberID,
        challengerID: challengerID,
        profile: nil,
        name: name,
        nickname: name,
        generation: "9기",
        school: "한성대",
        position: "",
        part: part,
        penalty: 0,
        rewardPoints: 0,
        badge: false,
        managementTeam: .challenger,
        attendanceRecords: [],
        penaltyHistory: []
    )
}

private func makePage(
    _ members: [MemberManagementItem],
    hasNext: Bool,
    currentPage: Int
) -> MemberPage {
    MemberPage(members: members, hasNext: hasNext, currentPage: currentPage)
}

/// 상벌점 히스토리 픽스처. `date` 는 결정론을 위해 epoch 0 고정입니다.
private func makeHistory(
    challengerPointId: String? = "P-1",
    pointType: ChallengerPointType = .studyLate,
    penaltyScore: Double = 2
) -> OperatorMemberPenaltyHistory {
    OperatorMemberPenaltyHistory(
        challengerPointId: challengerPointId,
        date: Date(timeIntervalSince1970: 0),
        reason: "사유",
        penaltyScore: penaltyScore,
        pointType: pointType
    )
}

/// `role` 은 `availablePointTypes` 테스트에만 영향을 주며, 그 외 테스트와는 무관합니다.
@MainActor
private func makeViewModel(
    useCase: MockFetchMembersUseCase,
    role: ManagementTeam = .schoolPresident
) -> MemberListViewModel {
    let session = UserSessionManager()
    session.updateRole(role)
    return MemberListViewModel(
        fetchMembersUseCase: useCase,
        errorHandler: ErrorHandler(),
        userSessionManager: session
    )
}

private struct DummyError: Error {}

// MARK: - Mock

private final class MockFetchMembersUseCase: @unchecked Sendable, FetchMembersUseCaseProtocol {

    // MARK: 상태 제어

    var pages: [Int: MemberPage] = [:]
    var executePageError: Error?
    var grantPointError: Error?
    var deletePointError: Error?
    var pointHistory: [OperatorMemberPenaltyHistory] = []
    var generationPoints: [GenerationPointSummary] = []
    var attendanceRecords: [MemberAttendanceRecord] = []
    var allGenerations: String = ""

    // MARK: 호출 기록

    private(set) var executePageCalls: [Int] = []
    private(set) var grantPointCalls: [(
        challengerId: String,
        pointType: ChallengerPointType,
        pointValue: Int,
        description: String
    )] = []
    private(set) var deletePointCalls: [String] = []

    // MARK: Protocol

    func execute() async throws -> [MemberManagementItem] {
        pages.values.flatMap(\.members)
    }

    func executePage(page: Int) async throws -> MemberPage {
        executePageCalls.append(page)
        if let executePageError { throw executePageError }
        return pages[page] ?? MemberPage(members: [], hasNext: false, currentPage: page)
    }

    func grantPoint(
        challengerId: String,
        pointType: ChallengerPointType,
        pointValue: Int,
        description: String
    ) async throws {
        grantPointCalls.append((challengerId, pointType, pointValue, description))
        if let grantPointError { throw grantPointError }
    }

    func deletePoint(challengerPointId: String) async throws {
        deletePointCalls.append(challengerPointId)
        if let deletePointError { throw deletePointError }
    }

    func fetchPointHistory(
        challengerId: String
    ) async throws -> [OperatorMemberPenaltyHistory] {
        pointHistory
    }

    func fetchAllGenerations(memberId: String) async throws -> String {
        allGenerations
    }

    func fetchGenerationPointSummaries(
        memberId: String
    ) async throws -> [GenerationPointSummary] {
        generationPoints
    }

    func fetchAttendanceRecords(
        memberId: String
    ) async throws -> [MemberAttendanceRecord] {
        attendanceRecords
    }
}

// MARK: - 첫 페이지 로딩

@MainActor
@Suite("MemberListViewModel — 첫 페이지 로딩 (도메인 규칙)")
struct MemberListViewModelFirstPageTests {

    @Test("첫 페이지 성공 → loaded 전이 + 페이지네이션 상태 반영")
    func firstPageLoadsAndSetsPagination() async {
        let first = makeMember(memberID: "1")
        let second = makeMember(memberID: "2")
        let useCase = MockFetchMembersUseCase()
        useCase.pages[0] = makePage([first, second], hasNext: true, currentPage: 0)
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchMembers()

        #expect(viewModel.membersState == .loaded([first, second]))
        #expect(viewModel.hasMorePages == true)
    }

    @Test("첫 페이지 실패 → failed 전이")
    func firstPageFailureSetsFailed() async {
        let useCase = MockFetchMembersUseCase()
        useCase.executePageError = DummyError()
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchMembers()

        #expect(viewModel.membersState.error != nil)
    }
}

// MARK: - 무한스크롤 페이지네이션

@MainActor
@Suite("MemberListViewModel — 무한스크롤 페이지네이션 (도메인 규칙)")
struct MemberListViewModelPaginationTests {

    @Test("다음 페이지 → 기존 목록에 추가 + 페이지네이션 갱신")
    func nextPageAppendsAndUpdatesPagination() async {
        let m1 = makeMember(memberID: "1")
        let m2 = makeMember(memberID: "2")
        let m3 = makeMember(memberID: "3")
        let m4 = makeMember(memberID: "4")
        let useCase = MockFetchMembersUseCase()
        useCase.pages[0] = makePage([m1, m2], hasNext: true, currentPage: 0)
        useCase.pages[1] = makePage([m3, m4], hasNext: false, currentPage: 1)
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchMembers()
        await viewModel.fetchNextPage()

        #expect(viewModel.membersState == .loaded([m1, m2, m3, m4]))
        #expect(viewModel.hasMorePages == false)
        #expect(useCase.executePageCalls == [0, 1])
    }

    @Test("다음 페이지에 기존 memberID 중복 → 중복 제거")
    func nextPageDeduplicatesByMemberID() async {
        let m1 = makeMember(memberID: "1")
        let m2 = makeMember(memberID: "2")
        let duplicated = makeMember(memberID: "2", name: "다른인스턴스")
        let m3 = makeMember(memberID: "3")
        let useCase = MockFetchMembersUseCase()
        useCase.pages[0] = makePage([m1, m2], hasNext: true, currentPage: 0)
        useCase.pages[1] = makePage([duplicated, m3], hasNext: false, currentPage: 1)
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchMembers()
        await viewModel.fetchNextPage()

        let loaded = viewModel.membersState.value ?? []
        #expect(loaded.map(\.memberID) == ["1", "2", "3"])
    }

    @Test("다음 페이지의 memberID nil 멤버 → nil끼리 중복으로 묶어 제거하지 않음")
    func nextPageKeepsNilMemberIDMembers() async {
        let m1 = makeMember(memberID: "1")
        let nilA = makeMember(memberID: nil, challengerID: "C-A", name: "A")
        let nilB = makeMember(memberID: nil, challengerID: "C-B", name: "B")
        let useCase = MockFetchMembersUseCase()
        useCase.pages[0] = makePage([m1, nilA], hasNext: true, currentPage: 0)
        useCase.pages[1] = makePage([nilB], hasNext: false, currentPage: 1)
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchMembers()
        await viewModel.fetchNextPage()

        let loaded = viewModel.membersState.value ?? []
        #expect(loaded.count == 3)
    }

    @Test("더 가져올 페이지 없음 → 다음 페이지 미요청")
    func nextPageNoOpWhenNoMorePages() async {
        let m1 = makeMember(memberID: "1")
        let useCase = MockFetchMembersUseCase()
        useCase.pages[0] = makePage([m1], hasNext: false, currentPage: 0)
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchMembers()
        await viewModel.fetchNextPage()

        #expect(useCase.executePageCalls == [0])
    }

    @Test("로딩 완료 전(.idle) → 다음 페이지 미요청")
    func nextPageNoOpWhenStateNotLoaded() async {
        let useCase = MockFetchMembersUseCase()
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchNextPage()

        #expect(useCase.executePageCalls.isEmpty)
    }

    @Test("다음 페이지 실패 → 기존 데이터 유지")
    func nextPageFailureRetainsExisting() async {
        let m1 = makeMember(memberID: "1")
        let m2 = makeMember(memberID: "2")
        let useCase = MockFetchMembersUseCase()
        useCase.pages[0] = makePage([m1, m2], hasNext: true, currentPage: 0)
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchMembers()
        useCase.executePageError = DummyError()
        await viewModel.fetchNextPage()

        #expect(viewModel.membersState == .loaded([m1, m2]))
        #expect(viewModel.isLoadingNextPage == false)
    }

    @Test("새로고침으로 마지막 페이지가 줄면 → 이후 fetchNextPage 가 스테일 페이지 미요청")
    func reloadShrinkPreventsStalePageRequest() async {
        let m0 = makeMember(memberID: "0", challengerID: "C-0")
        let m1 = makeMember(memberID: "1")
        let useCase = MockFetchMembersUseCase()
        useCase.pages[0] = makePage([m0], hasNext: true, currentPage: 0)
        useCase.pages[1] = makePage([m1], hasNext: true, currentPage: 1)
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchMembers()
        await viewModel.fetchNextPage()

        // 새로고침 시점에 데이터가 줄어 page 1 이 마지막(hasNext=false)이 됨
        useCase.pages[1] = makePage([m1], hasNext: false, currentPage: 1)
        _ = await viewModel.submitPoint(
            member: m0,
            pointType: .bestWorkbook,
            pointValue: 2,
            description: "x"
        )

        let callsBeforeNext = useCase.executePageCalls.count
        await viewModel.fetchNextPage()

        #expect(viewModel.hasMorePages == false)
        #expect(useCase.executePageCalls.count == callsBeforeNext)
    }
}

// MARK: - 검색·그룹핑

@MainActor
@Suite("MemberListViewModel — 검색·그룹핑 (도메인 규칙)")
struct MemberListViewModelSearchTests {

    @Test("Part별 그룹핑 → sortOrder 오름차순 정렬")
    func groupedMembersSortedByPartOrder() async {
        let iosMember = makeMember(memberID: "1", part: .front(type: .ios))
        let pmMember = makeMember(memberID: "2", part: .pm)
        let webMember = makeMember(memberID: "3", part: .front(type: .web))
        let useCase = MockFetchMembersUseCase()
        useCase.pages[0] = makePage(
            [iosMember, pmMember, webMember],
            hasNext: false,
            currentPage: 0
        )
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchMembers()

        #expect(viewModel.groupedMembers.map(\.part) == [
            .pm,
            .front(type: .web),
            .front(type: .ios),
        ])
    }

    @Test("검색어 → 이름 부분일치 필터")
    func searchFiltersByName() async {
        let hong = makeMember(memberID: "1", name: "홍길동")
        let kim = makeMember(memberID: "2", name: "김철수")
        let useCase = MockFetchMembersUseCase()
        useCase.pages[0] = makePage([hong, kim], hasNext: false, currentPage: 0)
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchMembers()
        viewModel.searchText = "김"

        let names = viewModel.groupedMembers.flatMap(\.members).map(\.name)
        #expect(names == ["김철수"])
    }

    @Test("검색 결과 없음 → isSearchResultEmpty true")
    func searchResultEmptyWhenNoMatch() async {
        let hong = makeMember(memberID: "1", name: "홍길동")
        let useCase = MockFetchMembersUseCase()
        useCase.pages[0] = makePage([hong], hasNext: false, currentPage: 0)
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchMembers()
        viewModel.searchText = "없는이름"

        #expect(viewModel.isSearchResultEmpty == true)
    }
}

// MARK: - 상벌점 부여 검증

@MainActor
@Suite("MemberListViewModel — 상벌점 부여 검증 (도메인 규칙)")
struct MemberListViewModelSubmitPointTests {

    @Test("빈 사유 → 부여 거부 + Alert + UseCase 미호출")
    func submitPointRejectsEmptyDescription() async {
        let member = makeMember(memberID: "1", challengerID: "C-1")
        let useCase = MockFetchMembersUseCase()
        let viewModel = makeViewModel(useCase: useCase)

        let granted = await viewModel.submitPoint(
            member: member,
            pointType: .bestWorkbook,
            pointValue: 2,
            description: "   "
        )

        #expect(granted == false)
        #expect(viewModel.alertPrompt != nil)
        #expect(useCase.grantPointCalls.isEmpty)
    }

    @Test("챌린저 ID 없음 → 부여 거부 + Alert + UseCase 미호출")
    func submitPointRejectsMissingChallengerID() async {
        let member = makeMember(memberID: "1", challengerID: nil)
        let useCase = MockFetchMembersUseCase()
        let viewModel = makeViewModel(useCase: useCase)

        let granted = await viewModel.submitPoint(
            member: member,
            pointType: .bestWorkbook,
            pointValue: 2,
            description: "잘했어요"
        )

        #expect(granted == false)
        #expect(viewModel.alertPrompt != nil)
        #expect(useCase.grantPointCalls.isEmpty)
    }

    @Test("정상 입력 → grantPoint 호출 + 성공 반환")
    func submitPointSucceedsAndCallsGrant() async {
        let member = makeMember(memberID: "1", challengerID: "C-1")
        let useCase = MockFetchMembersUseCase()
        useCase.pages[0] = makePage([member], hasNext: false, currentPage: 0)
        let viewModel = makeViewModel(useCase: useCase)

        let granted = await viewModel.submitPoint(
            member: member,
            pointType: .bestWorkbook,
            pointValue: 2,
            description: "잘했어요"
        )

        #expect(granted == true)
        #expect(useCase.grantPointCalls.first?.challengerId == "C-1")
        #expect(useCase.grantPointCalls.first?.pointType == .bestWorkbook)
    }

    @Test("부여 성공 후 새로고침 실패 → 성공 반환(서버 부여는 유효, 재시도 유발 X)")
    func submitPointReturnsTrueWhenReloadFails() async {
        let member = makeMember(memberID: "1", challengerID: "C-1")
        let useCase = MockFetchMembersUseCase()
        useCase.pages[0] = makePage([member], hasNext: false, currentPage: 0)
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchMembers()

        useCase.executePageError = DummyError()
        let granted = await viewModel.submitPoint(
            member: member,
            pointType: .bestWorkbook,
            pointValue: 2,
            description: "잘했어요"
        )

        #expect(granted == true)
        #expect(useCase.grantPointCalls.count == 1)
    }

    @Test("부여 후 새로고침 → 페이지네이션 상태(hasMorePages) 갱신")
    func submitPointReloadUpdatesPaginationState() async {
        let member = makeMember(memberID: "1", challengerID: "C-1")
        let useCase = MockFetchMembersUseCase()
        useCase.pages[0] = makePage([member], hasNext: true, currentPage: 0)
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchMembers()
        #expect(viewModel.hasMorePages == true)

        // 새로고침 시점에 해당 페이지가 마지막이 되어 hasNext=false 로 바뀐 상황
        useCase.pages[0] = makePage([member], hasNext: false, currentPage: 0)
        _ = await viewModel.submitPoint(
            member: member,
            pointType: .bestWorkbook,
            pointValue: 2,
            description: "잘했어요"
        )

        #expect(viewModel.hasMorePages == false)
    }

    @Test("부여 중 DomainError → Alert 표시 + 실패 반환")
    func submitPointShowsAlertOnDomainError() async {
        let member = makeMember(memberID: "1", challengerID: "C-1")
        let useCase = MockFetchMembersUseCase()
        useCase.grantPointError = DomainError.custom(message: "권한이 없습니다.")
        let viewModel = makeViewModel(useCase: useCase)

        let granted = await viewModel.submitPoint(
            member: member,
            pointType: .bestWorkbook,
            pointValue: 2,
            description: "사유"
        )

        #expect(granted == false)
        #expect(viewModel.alertPrompt != nil)
        #expect(useCase.grantPointCalls.count == 1)
    }
}

// MARK: - 포인트 삭제 검증

@MainActor
@Suite("MemberListViewModel — 포인트 삭제 검증 (도메인 규칙)")
struct MemberListViewModelDeletePointTests {

    @Test("포인트 ID 없음 → 안내 메시지 반환 + UseCase 미호출")
    func deletePointRejectsMissingPointID() async {
        let member = makeMember(memberID: "1", challengerID: "C-1")
        let history = makeHistory(challengerPointId: nil)
        let useCase = MockFetchMembersUseCase()
        let viewModel = makeViewModel(useCase: useCase)

        let message = await viewModel.deletePoint(member: member, history: history)

        #expect(message == "삭제할 포인트 ID를 찾을 수 없습니다.")
        #expect(useCase.deletePointCalls.isEmpty)
    }

    @Test("정상 삭제 → nil 반환 + deletePoint 호출")
    func deletePointSucceedsReturnsNil() async {
        let member = makeMember(memberID: "1", challengerID: "C-1")
        let history = makeHistory()
        let useCase = MockFetchMembersUseCase()
        useCase.pages[0] = makePage([member], hasNext: false, currentPage: 0)
        let viewModel = makeViewModel(useCase: useCase)

        let message = await viewModel.deletePoint(member: member, history: history)

        #expect(message == nil)
        #expect(useCase.deletePointCalls == ["P-1"])
    }

    @Test("삭제 성공 후 새로고침 실패 → nil 반환(서버 삭제는 유효)")
    func deletePointReturnsNilWhenReloadFails() async {
        let member = makeMember(memberID: "1", challengerID: "C-1")
        let history = makeHistory()
        let useCase = MockFetchMembersUseCase()
        useCase.pages[0] = makePage([member], hasNext: false, currentPage: 0)
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchMembers()

        useCase.executePageError = DummyError()
        let message = await viewModel.deletePoint(member: member, history: history)

        #expect(message == nil)
        #expect(useCase.deletePointCalls == ["P-1"])
    }

    @Test("삭제 중 DomainError → 해당 도메인 메시지 반환")
    func deletePointReturnsDomainErrorMessage() async {
        let member = makeMember(memberID: "1", challengerID: "C-1")
        let history = makeHistory()
        let error = DomainError.custom(message: "이미 삭제된 항목입니다.")
        let useCase = MockFetchMembersUseCase()
        useCase.deletePointError = error
        let viewModel = makeViewModel(useCase: useCase)

        let message = await viewModel.deletePoint(member: member, history: history)

        #expect(message == error.userMessage)
    }
}

// MARK: - 부여 가능 포인트 타입

@MainActor
@Suite("MemberListViewModel — 부여 가능 포인트 타입 (도메인 규칙)")
struct MemberListViewModelAvailableTypesTests {

    @Test(
        "부여 가능 타입은 역할 권한 레벨을 반영",
        arguments: [
            (role: ManagementTeam.challenger, isEmpty: true),
            (role: ManagementTeam.schoolPresident, isEmpty: false),
        ]
    )
    func availablePointTypesReflectRoleLevel(role: ManagementTeam, isEmpty: Bool) {
        let useCase = MockFetchMembersUseCase()
        let viewModel = makeViewModel(useCase: useCase, role: role)

        #expect(viewModel.availablePointTypes.isEmpty == isEmpty)
    }
}

// MARK: - 멤버 상세 조회

@MainActor
@Suite("MemberListViewModel — 멤버 상세 조회 (도메인 규칙)")
struct MemberListViewModelDetailTests {

    @Test("챌린저 ID 없는 멤버 → 상세 조회 없이 원본 멤버 그대로 선택")
    func detailWithoutChallengerIDKeepsRawMember() async {
        let member = makeMember(memberID: "1", challengerID: nil)
        let useCase = MockFetchMembersUseCase()
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.openChallengerMemberDetail(member)

        #expect(viewModel.selectedMember == member)
    }

    @Test("상세 조회 → 히스토리에서 상/벌 합계 집계 + 열람 권한 true")
    func detailAggregatesPenaltyAndRewardFromHistory() async {
        let member = makeMember(memberID: "1", challengerID: "C-1")
        let useCase = MockFetchMembersUseCase()
        useCase.pointHistory = [
            makeHistory(pointType: .studyLate, penaltyScore: 2),
            makeHistory(pointType: .bestWorkbook, penaltyScore: 3),
        ]
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.openChallengerMemberDetail(member)

        #expect(viewModel.selectedMember?.penalty == 2)
        #expect(viewModel.selectedMember?.rewardPoints == 3)
        #expect(viewModel.selectedMember?.canViewPenaltyHistory == true)
    }

    @Test("상세 조회 → 비어있지 않은 기수 텍스트로 generation 덮어쓰기")
    func detailOverridesGenerationWhenPresent() async {
        let member = makeMember(memberID: "1", challengerID: "C-1")
        let useCase = MockFetchMembersUseCase()
        useCase.allGenerations = "9기, 10기"
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.openChallengerMemberDetail(member)

        #expect(viewModel.selectedMember?.generation == "9기, 10기")
    }
}

#endif
