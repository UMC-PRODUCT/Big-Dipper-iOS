//
//  OperatorStudyManagementViewModelTests.swift
//  ActivityPresentationTests
//
//  Created by jaewon Lee on 6/27/26.
//

import Foundation
import Testing
import ActivityDomain
import CoreDomain
import UMCFoundation
@testable import ActivityPresentation

#if DEBUG

// MARK: - Helpers

private func makeMember(
    serverID: String,
    memberID: String? = nil,
    challengerID: String? = nil,
    name: String = "챌린저",
    role: StudyGroupMember.MemberRole = .member
) -> StudyGroupMember {
    StudyGroupMember(
        serverID: serverID,
        challengerID: challengerID,
        memberID: memberID ?? serverID,
        name: name,
        university: "한성대학교",
        role: role
    )
}

private func makeGroup(
    serverID: String = "G-1",
    name: String = "iOS 스터디",
    part: UMCPartType = .front(type: .ios),
    mentors: [StudyGroupMember] = [],
    members: [StudyGroupMember] = []
) -> StudyGroupInfo {
    StudyGroupInfo(
        serverID: serverID,
        name: name,
        part: part,
        createdDate: Date(timeIntervalSince1970: 1_000),
        mentors: mentors,
        members: members
    )
}

private func makeChallenger(
    memberId: String,
    challengerId: String? = nil,
    gen: String = "",
    name: String = "챌린저",
    part: UMCPartType = .front(type: .ios)
) -> ChallengerInfo {
    ChallengerInfo(
        memberId: memberId,
        challengerId: challengerId,
        gen: gen,
        name: name,
        nickname: name,
        schoolName: "한성대학교",
        profileImage: nil,
        part: part
    )
}

private func makePage(
    content: [StudyGroupInfo],
    hasNext: Bool = false,
    nextCursor: String? = nil
) -> StudyGroupDetailsPage {
    StudyGroupDetailsPage(content: content, hasNext: hasNext, nextCursor: nextCursor)
}

@MainActor
private func makeViewModel(
    useCase: MockOperatorStudyManagementUseCase,
    errorHandler: ErrorHandler = ErrorHandler(),
    gisuId: String? = "11",
    challengerId: String? = "C-1"
) -> OperatorStudyManagementViewModel {
    OperatorStudyManagementViewModel(
        errorHandler: errorHandler,
        useCase: useCase,
        gisuIdProvider: { gisuId },
        challengerIdProvider: { challengerId }
    )
}

// drainUntil 은 Tests 타깃 공용 `ConcurrencyTestSupport.swift` 의 헬퍼를 사용한다.

private struct DummyError: Error {}

// MARK: - Mock

private final class MockOperatorStudyManagementUseCase: @unchecked Sendable,
    OperatorStudyManagementUseCaseProtocol {

    // 페이지: 호출 순서대로 소비. 모두 소비되면 빈 페이지 반환.
    var pageResults: [StudyGroupDetailsPage] = []
    var pageError: Error?
    private var pageIndex = 0
    private(set) var fetchPageCalls: [(cursor: String?, size: Int)] = []

    // resolve: memberId → challengerId (없으면 resolveDefault)
    var resolveMap: [String: String?] = [:]
    var resolveDefault: String?
    var resolveError: Error?
    private(set) var resolveCalls: [(memberId: String, preferredGeneration: String?)] = []

    var createError: Error?
    private(set) var createCalls: [(
        gisuId: String,
        name: String,
        part: UMCPartType,
        memberIds: [String],
        mentorIds: [String]
    )] = []

    var updateError: Error?
    private(set) var updateCalls: [(groupId: String, name: String)] = []

    var deleteError: Error?
    private(set) var deleteCalls: [String] = []

    var addMemberError: Error?
    private(set) var addMemberCalls: [(groupId: String, memberId: String)] = []
    var removeMemberError: Error?
    private(set) var removeMemberCalls: [(groupId: String, memberId: String)] = []
    var addMentorError: Error?
    private(set) var addMentorCalls: [(groupId: String, mentorId: String)] = []
    var removeMentorError: Error?
    private(set) var removeMentorCalls: [(groupId: String, mentorId: String)] = []

    // 제출 현황: 페이지 결과를 호출 순서대로 소비. 모두 소비되면 빈 페이지 반환.
    var submissionPages: [StudyMemberSubmissionPage] = []
    var submissionError: Error?
    private var submissionIndex = 0
    private(set) var submissionCalls: [(
        studyGroupId: String?,
        weekNos: [String],
        cursor: String?,
        size: Int
    )] = []

    var groupNames: [StudyGroupName] = []
    var groupNamesError: Error?
    private(set) var groupNamesCallCount = 0

    /// 제출 현황 응답을 ``releaseSubmissions()`` 까지 붙잡아 둘지 여부.
    var gateSubmissions = false
    private var submissionContinuations: [CheckedContinuation<Void, Never>] = []

    /// 그룹 필터별 응답 (키: `studyGroupId`, 전체 그룹은 `""`).
    ///
    /// 지정하면 FIFO 큐 대신 이 매핑을 사용한다. 게이트로 여러 요청을 동시에 띄우면 재개 순서에
    /// 따라 FIFO 큐의 소비 순서가 흔들려 테스트가 불안정해지므로, 레이스 테스트는 **요청 인자**로
    /// 응답을 고정한다.
    var submissionPagesByGroupId: [String: StudyMemberSubmissionPage] = [:]

    func fetchStudyGroupDetailsPage(
        cursor: String?,
        size: Int
    ) async throws -> StudyGroupDetailsPage {
        if let pageError { throw pageError }
        fetchPageCalls.append((cursor, size))
        defer { pageIndex += 1 }
        return pageIndex < pageResults.count
            ? pageResults[pageIndex]
            : makePage(content: [])
    }

    func resolveChallengerId(
        memberId: String,
        preferredGeneration: String?
    ) async throws -> String? {
        if let resolveError { throw resolveError }
        resolveCalls.append((memberId, preferredGeneration))
        if let mapped = resolveMap[memberId] { return mapped }
        return resolveDefault
    }

    func fetchStudyGroupNames() async throws -> [StudyGroupName] {
        groupNamesCallCount += 1
        if let groupNamesError { throw groupNamesError }
        return groupNames
    }

    func fetchStudyMemberSubmissions(
        studyGroupId: String?,
        weekNos: [String],
        cursor: String?,
        size: Int
    ) async throws -> StudyMemberSubmissionPage {
        submissionCalls.append((studyGroupId, weekNos, cursor, size))

        // 게이트가 열려 있으면 응답을 붙잡아 둔다 — 필터 변경과 응답 도착 순서를
        // 결정론적으로 뒤집어 stale 응답 경로를 재현하기 위함.
        if gateSubmissions {
            await withCheckedContinuation { continuation in
                submissionContinuations.append(continuation)
            }
        }

        if let submissionError { throw submissionError }

        if !submissionPagesByGroupId.isEmpty {
            return submissionPagesByGroupId[studyGroupId ?? ""]
                ?? StudyMemberSubmissionPage(content: [], hasNext: false, nextCursor: nil)
        }

        defer { submissionIndex += 1 }
        return submissionIndex < submissionPages.count
            ? submissionPages[submissionIndex]
            : StudyMemberSubmissionPage(content: [], hasNext: false, nextCursor: nil)
    }

    /// 게이트에 걸려 실제로 대기 중인 호출 수.
    ///
    /// `submissionCalls` 는 suspend **전에** 기록되므로, 호출 수만 보고 재개하면 아직 대기열에
    /// 등록되지 않은 호출이 영영 깨어나지 못한다. 게이트 테스트는 이 값으로 기다린다.
    var pendingSubmissionCount: Int { submissionContinuations.count }

    /// 붙잡아 둔 제출 현황 호출을 **최신 요청부터** 재개한다.
    ///
    /// 역순으로 재개해야 오래된 요청의 응답이 **마지막에** 도착한다. 토큰 가드가 없으면 그
    /// 응답이 최신 목록을 덮어쓰는데, 순서대로(FIFO) 재개하면 최신 응답이 나중에 도착해
    /// 가드가 없어도 결과가 맞아떨어져 회귀를 놓친다.
    func releaseSubmissions() {
        let pending = submissionContinuations
        submissionContinuations.removeAll()
        pending.reversed().forEach { $0.resume() }
    }

    func createStudyGroup(
        gisuId: String,
        name: String,
        part: UMCPartType,
        memberIds: [String],
        mentorIds: [String]
    ) async throws {
        if let createError { throw createError }
        createCalls.append((gisuId, name, part, memberIds, mentorIds))
    }

    func updateStudyGroup(groupId: String, name: String) async throws {
        if let updateError { throw updateError }
        updateCalls.append((groupId, name))
    }

    func deleteStudyGroup(groupId: String) async throws {
        if let deleteError { throw deleteError }
        deleteCalls.append(groupId)
    }

    func addStudyGroupMember(groupId: String, memberId: String) async throws {
        if let addMemberError { throw addMemberError }
        addMemberCalls.append((groupId, memberId))
    }

    func removeStudyGroupMember(groupId: String, memberId: String) async throws {
        if let removeMemberError { throw removeMemberError }
        removeMemberCalls.append((groupId, memberId))
    }

    func addStudyGroupMentor(groupId: String, mentorId: String) async throws {
        if let addMentorError { throw addMentorError }
        addMentorCalls.append((groupId, mentorId))
    }

    func removeStudyGroupMentor(groupId: String, mentorId: String) async throws {
        if let removeMentorError { throw removeMentorError }
        removeMentorCalls.append((groupId, mentorId))
    }
}

// MARK: - 그룹 목록 로딩 / 페이지네이션

@MainActor
@Suite("OperatorStudyManagementViewModel — 그룹 목록 로딩 (도메인 규칙)")
struct OperatorStudyManagementViewModelLoadTests {

    @Test("최초 조회 성공 → loaded 전이 + 커서/다음 페이지 상태 반영")
    func fetchSucceedsAndStoresCursor() async {
        let useCase = MockOperatorStudyManagementUseCase()
        let group = makeGroup(serverID: "G-1")
        useCase.pageResults = [makePage(content: [group], hasNext: true, nextCursor: "10")]
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchGroupManagementData()

        #expect(viewModel.studyGroupDetails.map(\.serverID) == ["G-1"])
        #expect(viewModel.studyGroupDetailsState == .loaded([group]))
    }

    @Test("최초 조회 실패(DomainError) → failed(.domain) 전이")
    func fetchFailsWithDomainError() async {
        let useCase = MockOperatorStudyManagementUseCase()
        useCase.pageError = DomainError.custom(message: "실패")
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchGroupManagementData()

        #expect(viewModel.studyGroupDetailsState == .failed(.domain(.custom(message: "실패"))))
    }

    @Test("다음 페이지 — 마지막 카드 도달 시 커서로 추가 로드 + serverID 중복 제거")
    func loadMoreAppendsDedupedByServerID() async {
        let useCase = MockOperatorStudyManagementUseCase()
        let g1 = makeGroup(serverID: "G-1")
        let g2 = makeGroup(serverID: "G-2", name: "Web 스터디")
        useCase.pageResults = [
            makePage(content: [g1], hasNext: true, nextCursor: "10"),
            // 2페이지가 g1(중복) + g2 를 반환해도 g2 만 추가돼야 함
            makePage(content: [g1, g2], hasNext: false, nextCursor: nil)
        ]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchGroupManagementData()

        await viewModel.loadMoreGroupManagementDataIfNeeded(currentGroupID: g1.id)

        #expect(viewModel.studyGroupDetails.map(\.serverID) == ["G-1", "G-2"])
        #expect(useCase.fetchPageCalls.count == 2)
        #expect(useCase.fetchPageCalls.last?.cursor == "10")
    }

    @Test("다음 페이지 — 마지막 카드가 아니면 추가 로드 안 함")
    func loadMoreSkipsWhenNotLastCard() async {
        let useCase = MockOperatorStudyManagementUseCase()
        let g1 = makeGroup(serverID: "G-1")
        useCase.pageResults = [makePage(content: [g1], hasNext: true, nextCursor: "10")]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchGroupManagementData()

        await viewModel.loadMoreGroupManagementDataIfNeeded(currentGroupID: UUID())

        #expect(useCase.fetchPageCalls.count == 1)
    }

    @Test("생성 후 백그라운드 새로고침 — 로드된 페이지 윈도우를 복원해 첫 페이지로 잘리지 않는다")
    func refreshRestoresLoadedPageWindowAfterCreate() async throws {
        let useCase = MockOperatorStudyManagementUseCase()
        let page1 = (1...20).map { makeGroup(serverID: "G-\($0)") }
        let page2 = (21...40).map { makeGroup(serverID: "G-\($0)") }
        // 페이지 소비 순서: [최초 조회][loadMore][새로고침 1p][새로고침 2p]
        useCase.pageResults = [
            makePage(content: page1, hasNext: true, nextCursor: "c1"),
            makePage(content: page2, hasNext: false),
            makePage(content: page1, hasNext: true, nextCursor: "c1"),
            makePage(content: page2, hasNext: false)
        ]
        let viewModel = makeViewModel(useCase: useCase, gisuId: "11")

        // 사용자가 2페이지(40개)까지 스크롤한 상태 재현
        await viewModel.fetchGroupManagementData()
        let lastCard = try #require(viewModel.studyGroupDetails.last)
        await viewModel.loadMoreGroupManagementDataIfNeeded(currentGroupID: lastCard.id)
        #expect(viewModel.studyGroupDetails.count == 40)

        // 그룹 생성 → 백그라운드 새로고침 트리거
        let created = await viewModel.createGroup(
            name: "새 스터디",
            part: .front(type: .ios),
            mentors: [makeChallenger(memberId: "9", challengerId: "909")],
            members: []
        )
        #expect(created == true)

        // 새로고침 Task 가 placeholder 를 서버 데이터로 교체할 때까지 대기
        await drainUntil {
            !viewModel.studyGroupDetails.contains { $0.serverID.hasPrefix("new_") }
        }

        // 첫 페이지(20)로 잘리지 않고 로드 윈도우(40)가 복원돼야 한다.
        #expect(viewModel.studyGroupDetails.count == 40)
        #expect(viewModel.studyGroupDetails.map(\.serverID).contains("G-40"))
    }
}

// MARK: - 그룹 생성

@MainActor
@Suite("OperatorStudyManagementViewModel — 그룹 생성 (도메인 규칙)")
struct OperatorStudyManagementViewModelCreateTests {

    @Test(
        "입력 검증 실패 → 생성 미요청 + Alert",
        arguments: [
            (name: "", hasMentor: true, gisuId: "11"),
            (name: "iOS", hasMentor: false, gisuId: "11"),
            (name: "iOS", hasMentor: true, gisuId: nil)
        ]
    )
    func createRejectsInvalidInput(
        name: String,
        hasMentor: Bool,
        gisuId: String?
    ) async {
        let useCase = MockOperatorStudyManagementUseCase()
        let viewModel = makeViewModel(useCase: useCase, gisuId: gisuId)
        let mentors = hasMentor ? [makeChallenger(memberId: "9", challengerId: "909")] : []

        let created = await viewModel.createGroup(
            name: name,
            part: .front(type: .ios),
            mentors: mentors,
            members: []
        )

        #expect(created == false)
        #expect(useCase.createCalls.isEmpty)
        #expect(viewModel.alertPrompt != nil)
    }

    @Test("생성 성공 → 멘토와 중복된 멤버는 memberIds 에서 제외 + 낙관적 삽입")
    func createSucceedsAndSplitsMentorMemberIds() async throws {
        let useCase = MockOperatorStudyManagementUseCase()
        let viewModel = makeViewModel(useCase: useCase, gisuId: "11")
        let mentor = makeChallenger(memberId: "9", challengerId: "909")
        let memberA = makeChallenger(memberId: "1", challengerId: "101")
        let mentorClone = makeChallenger(memberId: "9", challengerId: "909")

        let created = await viewModel.createGroup(
            name: "iOS 스터디",
            part: .front(type: .ios),
            mentors: [mentor],
            members: [memberA, mentorClone]
        )

        #expect(created == true)
        let call = try #require(useCase.createCalls.first)
        #expect(call.gisuId == "11")
        #expect(call.mentorIds == ["909"])
        #expect(call.memberIds == ["101"])  // 909(멘토)는 제외
        // 낙관적 삽입: 백그라운드 새로고침 전 상태를 즉시 검증
        #expect(viewModel.studyGroupDetails.first?.name == "iOS 스터디")
    }

    @Test("생성 — challengerId 가 memberId 와 같으면 resolve 로 해석")
    func createResolvesChallengerIdWhenNotDistinct() async {
        let useCase = MockOperatorStudyManagementUseCase()
        useCase.resolveMap = ["5": "505"]
        let viewModel = makeViewModel(useCase: useCase, gisuId: "11")
        // challengerId == memberId → 구분 불가 → resolve 위임
        let mentor = makeChallenger(memberId: "5", challengerId: "5")

        let created = await viewModel.createGroup(
            name: "iOS 스터디",
            part: .front(type: .ios),
            mentors: [mentor],
            members: []
        )

        #expect(created == true)
        #expect(useCase.resolveCalls.map(\.memberId) == ["5"])
        #expect(useCase.createCalls.first?.mentorIds == ["505"])
    }

    @Test("생성 403(AUTHORIZATION) → 권한 안내 Alert + 실패 반환")
    func createPresentsPermissionAlertOn403() async {
        let useCase = MockOperatorStudyManagementUseCase()
        let body = Data(#"{"code":"AUTHORIZATION-0002"}"#.utf8)
        useCase.createError = NetworkError.requestFailed(statusCode: 403, data: body)
        let viewModel = makeViewModel(useCase: useCase, gisuId: "11")

        let created = await viewModel.createGroup(
            name: "iOS 스터디",
            part: .front(type: .ios),
            mentors: [makeChallenger(memberId: "9", challengerId: "909")],
            members: []
        )

        #expect(created == false)
        #expect(viewModel.alertPrompt?.title == "그룹 생성 실패")
        #expect(viewModel.alertPrompt?.message.hasPrefix("현재 계정 권한으로는") == true)
    }

    @Test("생성 403 — AUTHORIZATION-0002 가 아닌 코드는 권한 템플릿이 아니라 서버 메시지를 보여준다")
    func createShowsServerMessageForOther403() async {
        let useCase = MockOperatorStudyManagementUseCase()
        let body = Data(#"{"code":"STUDY-403","message":"이미 존재하는 그룹입니다."}"#.utf8)
        useCase.createError = NetworkError.requestFailed(statusCode: 403, data: body)
        let viewModel = makeViewModel(useCase: useCase, gisuId: "11")

        let created = await viewModel.createGroup(
            name: "iOS 스터디",
            part: .front(type: .ios),
            mentors: [makeChallenger(memberId: "9", challengerId: "909")],
            members: []
        )

        #expect(created == false)
        #expect(viewModel.alertPrompt?.message == "이미 존재하는 그룹입니다.")
        #expect(viewModel.alertPrompt?.message.hasPrefix("현재 계정 권한으로는") == false)
    }

    @Test(
        "생성 비-403 에러 — 서버 메시지 body 가 있어도 로컬 Alert 로 소화하지 않고 errorHandler 로 전파",
        arguments: [401, 404, 409, 500]
    )
    func createDoesNotSwallowNon403ServerMessage(statusCode: Int) async {
        let useCase = MockOperatorStudyManagementUseCase()
        let body = Data(#"{"message":"서버가 내려준 실패 메시지"}"#.utf8)
        useCase.createError = NetworkError.requestFailed(statusCode: statusCode, data: body)
        let viewModel = makeViewModel(useCase: useCase, gisuId: "11")

        let created = await viewModel.createGroup(
            name: "iOS 스터디",
            part: .front(type: .ios),
            mentors: [makeChallenger(memberId: "9", challengerId: "909")],
            members: []
        )

        #expect(created == false)
        // 비-403 은 로컬 Alert(권한/서버 메시지)로 소화되지 않아야 한다 → alertPrompt 는 nil,
        // 에러는 errorHandler 경로로 흘러간다.
        #expect(viewModel.alertPrompt == nil)
    }

    // MARK: - RepositoryError 경로 (NetworkError 오버로드와 동일한 범위 게이트)

    @Test(
        "생성 RepositoryError — 권한 거부 코드는 서버 메시지를 로컬 Alert 로 보여준다",
        arguments: ["AUTHORIZATION-0001", "AUTHORIZATION-0002", "ORGANIZATION-0031"]
    )
    func createPresentsAlertForRepositoryPermissionCode(code: String) async {
        let useCase = MockOperatorStudyManagementUseCase()
        useCase.createError = RepositoryError.serverError(
            code: code,
            message: "스터디 그룹을 만들 권한이 없어요."
        )
        let viewModel = makeViewModel(useCase: useCase, gisuId: "11")

        let created = await viewModel.createGroup(
            name: "iOS 스터디",
            part: .front(type: .ios),
            mentors: [makeChallenger(memberId: "9", challengerId: "909")],
            members: []
        )

        #expect(created == false)
        #expect(viewModel.alertPrompt?.title == "그룹 생성 실패")
        #expect(viewModel.alertPrompt?.message == "스터디 그룹을 만들 권한이 없어요.")
    }

    /// 권한 거부가 아닌 실패는 message 가 있어도 로컬 Alert 로 소화하지 않는다.
    ///
    /// `AUTHORIZATION-0003`(400)·`-0004`(500)·`-0010`(404) 는 권한 코드와 **접두사가 같지만**
    /// 권한 거부가 아니다 — 접두사 매칭으로 게이트하면 이 케이스들이 잘못 소화된다.
    @Test(
        "생성 RepositoryError — 권한 거부가 아닌 코드는 소화하지 않고 errorHandler 로 전파",
        arguments: [
            "JWT-0002",             // 세션 만료 (401)
            "AUTHORIZATION-0003",   // 같은 접두사지만 400 (권한 값 오류)
            "AUTHORIZATION-0004",   // 같은 접두사지만 500 (정책 평가 실패)
            "AUTHORIZATION-0010",   // 같은 접두사지만 404 (역할 없음)
            "COMMON-500",           // 서버 오류
            "STUDY-9999"            // 미정의 코드
        ]
    )
    func createDoesNotSwallowRepositoryNonPermissionCode(code: String) async {
        let useCase = MockOperatorStudyManagementUseCase()
        useCase.createError = RepositoryError.serverError(
            code: code,
            message: "서버가 내려준 실패 메시지"
        )
        let viewModel = makeViewModel(useCase: useCase, gisuId: "11")

        let created = await viewModel.createGroup(
            name: "iOS 스터디",
            part: .front(type: .ios),
            mentors: [makeChallenger(memberId: "9", challengerId: "909")],
            members: []
        )

        #expect(created == false)
        #expect(viewModel.alertPrompt == nil)
    }

    @Test("생성 RepositoryError — 권한 코드라도 message 가 비면 소화하지 않고 전파")
    func createDoesNotSwallowRepositoryPermissionCodeWithoutMessage() async {
        let useCase = MockOperatorStudyManagementUseCase()
        useCase.createError = RepositoryError.serverError(
            code: "AUTHORIZATION-0002",
            message: "   "
        )
        let viewModel = makeViewModel(useCase: useCase, gisuId: "11")

        let created = await viewModel.createGroup(
            name: "iOS 스터디",
            part: .front(type: .ios),
            mentors: [makeChallenger(memberId: "9", challengerId: "909")],
            members: []
        )

        #expect(created == false)
        #expect(viewModel.alertPrompt == nil)
    }
}

// MARK: - 그룹 수정 / 삭제

@MainActor
@Suite("OperatorStudyManagementViewModel — 그룹 수정/삭제 (도메인 규칙)")
struct OperatorStudyManagementViewModelEditTests {

    @Test("이름 수정 성공 → UseCase 위임 + 로컬 이름 갱신")
    func updateSucceedsAndUpdatesLocalName() async {
        let useCase = MockOperatorStudyManagementUseCase()
        let group = makeGroup(serverID: "G-1", name: "옛 이름")
        useCase.pageResults = [makePage(content: [group])]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchGroupManagementData()

        let updated = await viewModel.updateGroup(groupID: group.id, name: "새 이름")

        #expect(updated == true)
        #expect(useCase.updateCalls.first?.groupId == "G-1")
        #expect(viewModel.studyGroupDetails.first?.name == "새 이름")
    }

    @Test("이름 수정 — 빈 이름은 거부")
    func updateRejectsEmptyName() async {
        let useCase = MockOperatorStudyManagementUseCase()
        let group = makeGroup(serverID: "G-1")
        useCase.pageResults = [makePage(content: [group])]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchGroupManagementData()

        let updated = await viewModel.updateGroup(groupID: group.id, name: "   ")

        #expect(updated == false)
        #expect(useCase.updateCalls.isEmpty)
        #expect(viewModel.alertPrompt != nil)
    }

    @Test("이름 수정 — 낙관적 placeholder 그룹은 서버 호출 차단")
    func updateRejectsLocalPlaceholderGroup() async {
        let useCase = MockOperatorStudyManagementUseCase()
        let placeholder = makeGroup(serverID: "new_LOCAL")
        useCase.pageResults = [makePage(content: [placeholder])]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchGroupManagementData()

        let updated = await viewModel.updateGroup(groupID: placeholder.id, name: "새 이름")

        #expect(updated == false)
        #expect(useCase.updateCalls.isEmpty)
    }

    @Test("삭제 성공 → UseCase 위임 + 로컬 목록에서 제거")
    func deleteSucceedsAndRemovesLocally() async {
        let useCase = MockOperatorStudyManagementUseCase()
        let group = makeGroup(serverID: "G-1")
        useCase.pageResults = [makePage(content: [group])]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchGroupManagementData()

        await viewModel.deleteGroup(group)

        #expect(useCase.deleteCalls == ["G-1"])
        #expect(viewModel.studyGroupDetails.isEmpty)
    }

    @Test("삭제 — 낙관적 placeholder 그룹은 서버 호출 차단 + Alert")
    func deleteRejectsLocalPlaceholderGroup() async {
        let useCase = MockOperatorStudyManagementUseCase()
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.deleteGroup(makeGroup(serverID: "new_LOCAL"))

        #expect(useCase.deleteCalls.isEmpty)
        #expect(viewModel.alertPrompt != nil)
    }
}

// MARK: - 멤버 / 멘토 변경

@MainActor
@Suite("OperatorStudyManagementViewModel — 멤버/멘토 변경 (도메인 규칙)")
struct OperatorStudyManagementViewModelMembershipTests {

    @Test("멤버 적용 — 추가/제거 diff 만 서버 호출 + 로컬 반영")
    func applySelectedChallengersSendsOnlyDiff() async {
        let useCase = MockOperatorStudyManagementUseCase()
        let memberA = makeMember(serverID: "1", memberID: "1", challengerID: "101")
        let memberB = makeMember(serverID: "2", memberID: "2", challengerID: "102")
        let group = makeGroup(serverID: "G-1", members: [memberA, memberB])
        useCase.pageResults = [makePage(content: [group])]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchGroupManagementData()

        viewModel.showAddMemberSheet(for: group)
        // B 제거, C 추가
        viewModel.selectedChallengers = [
            makeChallenger(memberId: "1", challengerId: "101"),
            makeChallenger(memberId: "3", challengerId: "103")
        ]

        await viewModel.applySelectedChallengers()

        #expect(useCase.addMemberCalls.map(\.memberId) == ["103"])
        #expect(useCase.removeMemberCalls.map(\.memberId) == ["102"])
        #expect(viewModel.studyGroupDetails.first?.members.map(\.memberID) == ["1", "3"])
    }

    @Test("멤버 적용 — 변경 없음이면 서버 호출 안 함")
    func applySelectedChallengersSkipsWhenUnchanged() async {
        let useCase = MockOperatorStudyManagementUseCase()
        let memberA = makeMember(serverID: "1", memberID: "1", challengerID: "101")
        let group = makeGroup(serverID: "G-1", members: [memberA])
        useCase.pageResults = [makePage(content: [group])]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchGroupManagementData()

        viewModel.showAddMemberSheet(for: group)
        // 선택을 그대로 유지 (변경 없음)
        await viewModel.applySelectedChallengers()

        #expect(useCase.addMemberCalls.isEmpty)
        #expect(useCase.removeMemberCalls.isEmpty)
    }

    @Test("멘토 적용 — 추가/제거 diff 만 서버 호출 + 로컬 반영")
    func applySelectedMentorsSendsOnlyDiff() async {
        let useCase = MockOperatorStudyManagementUseCase()
        let mentorA = makeMember(serverID: "9", memberID: "9", challengerID: "909", role: .leader)
        let mentorB = makeMember(serverID: "8", memberID: "8", challengerID: "808", role: .leader)
        let group = makeGroup(serverID: "G-1", mentors: [mentorA, mentorB])
        useCase.pageResults = [makePage(content: [group])]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchGroupManagementData()

        viewModel.showAddMentorSheet(for: group)
        // B(808) 제거, C(707) 추가
        viewModel.selectedMentors = [
            makeChallenger(memberId: "9", challengerId: "909"),
            makeChallenger(memberId: "7", challengerId: "707")
        ]

        await viewModel.applySelectedMentors()

        #expect(useCase.addMentorCalls.map(\.mentorId) == ["707"])
        #expect(useCase.removeMentorCalls.map(\.mentorId) == ["808"])
        #expect(viewModel.studyGroupDetails.first?.mentors.map(\.memberID) == ["9", "7"])
    }

    @Test("멘토 단건 삭제 — 마지막 멘토는 차단")
    func removeMentorBlocksLastOne() async {
        let useCase = MockOperatorStudyManagementUseCase()
        let onlyMentor = makeMember(serverID: "9", challengerID: "909", role: .leader)
        let group = makeGroup(serverID: "G-1", mentors: [onlyMentor])
        useCase.pageResults = [makePage(content: [group])]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchGroupManagementData()

        await viewModel.removeMentor(onlyMentor, from: group)

        #expect(useCase.removeMentorCalls.isEmpty)
        #expect(viewModel.alertPrompt?.title == "삭제 불가")
        #expect(viewModel.studyGroupDetails.first?.mentors.count == 1)
    }

    @Test("멘토 단건 삭제 — 2명 이상이면 제거 위임 + 로컬 반영")
    func removeMentorSucceedsWhenMoreThanOne() async {
        let useCase = MockOperatorStudyManagementUseCase()
        let mentorA = makeMember(serverID: "9", challengerID: "909", role: .leader)
        let mentorB = makeMember(serverID: "8", challengerID: "808", role: .leader)
        let group = makeGroup(serverID: "G-1", mentors: [mentorA, mentorB])
        useCase.pageResults = [makePage(content: [group])]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchGroupManagementData()

        await viewModel.removeMentor(mentorA, from: group)

        #expect(useCase.removeMentorCalls.map(\.mentorId) == ["909"])
        #expect(viewModel.studyGroupDetails.first?.mentors.map(\.serverID) == ["8"])
    }

    @Test("멤버 단건 삭제 — 제거 위임 + 로컬 반영")
    func removeMemberSucceeds() async {
        let useCase = MockOperatorStudyManagementUseCase()
        let memberA = makeMember(serverID: "1", challengerID: "101")
        let group = makeGroup(serverID: "G-1", members: [memberA])
        useCase.pageResults = [makePage(content: [group])]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchGroupManagementData()

        await viewModel.removeMember(memberA, from: group)

        #expect(useCase.removeMemberCalls.map(\.memberId) == ["101"])
        #expect(viewModel.studyGroupDetails.first?.members.isEmpty == true)
    }
}

// MARK: - 시트 표시

@MainActor
@Suite("OperatorStudyManagementViewModel — 시트 표시 (도메인 규칙)")
struct OperatorStudyManagementViewModelSheetTests {

    @Test("편집 시트 — 현재 이름을 입력 상태로 시드")
    func showEditSheetSeedsName() {
        let useCase = MockOperatorStudyManagementUseCase()
        let viewModel = makeViewModel(useCase: useCase)
        let group = makeGroup(serverID: "G-1", name: "iOS 스터디")

        viewModel.showEditSheet(for: group)

        #expect(viewModel.editingName == "iOS 스터디")
        #expect(viewModel.editingGroup?.id == group.id)
    }

    @Test("멤버 추가 시트 — 기존 멤버를 선택 목록으로 변환")
    func showAddMemberSheetBuildsSelection() {
        let useCase = MockOperatorStudyManagementUseCase()
        let viewModel = makeViewModel(useCase: useCase)
        let members = [
            makeMember(serverID: "1", memberID: "1", challengerID: "101"),
            makeMember(serverID: "2", memberID: "2", challengerID: "102")
        ]
        let group = makeGroup(serverID: "G-1", members: members)

        viewModel.showAddMemberSheet(for: group)

        #expect(viewModel.selectedChallengers.map(\.memberId) == ["1", "2"])
        #expect(viewModel.addMemberGroup?.id == group.id)
    }
}

// MARK: - 일정 등록 권한

/// 일정 등록 권한 판정의 입력 조합.
private struct ScheduleAuthorizationCase: Sendable, CustomTestStringConvertible {

    /// 로컬에 저장된 본인 챌린저 ID. `nil`·빈 문자열은 "신원 미상".
    let storedChallengerId: String?

    /// 그룹 멘토들의 챌린저 ID. 원소 `nil` 은 서버가 값을 주지 않은 멘토.
    let mentorChallengerIds: [String?]

    let canRegister: Bool

    var testDescription: String {
        let mentors = mentorChallengerIds.map { $0 ?? "nil" }.joined(separator: ",")
        return "본인=\(storedChallengerId ?? "nil") 멘토=[\(mentors)] → \(canRegister)"
    }
}

private let scheduleAuthorizationCases: [ScheduleAuthorizationCase] = [
    .init(storedChallengerId: "C-1", mentorChallengerIds: ["C-1"], canRegister: true),
    .init(storedChallengerId: "C-9", mentorChallengerIds: ["C-1"], canRegister: false),
    .init(storedChallengerId: "C-1", mentorChallengerIds: [], canRegister: false),
    .init(storedChallengerId: "C-1", mentorChallengerIds: [nil], canRegister: false),
    .init(storedChallengerId: nil, mentorChallengerIds: ["C-1"], canRegister: false),
    .init(storedChallengerId: "", mentorChallengerIds: ["C-1"], canRegister: false),
]

@MainActor
@Suite("OperatorStudyManagementViewModel — 일정 등록 권한 (도메인 규칙)")
struct OperatorStudyManagementScheduleAuthorizationTests {

    /// 담당 멘토 본인만 통과한다. 신원을 확인하지 못한 상태(저장 ID 부재, 멘토 ID 미상)를
    /// 통과시키면 남의 스터디 일정을 등록할 수 있게 되므로 모두 거부한다.
    @Test("멘토 명단과 본인 ID 대조로 등록 권한이 갈린다", arguments: scheduleAuthorizationCases)
    fileprivate func scheduleAuthorizationFollowsMentorRoster(
        testCase: ScheduleAuthorizationCase
    ) {
        let useCase = MockOperatorStudyManagementUseCase()
        let viewModel = makeViewModel(
            useCase: useCase,
            challengerId: testCase.storedChallengerId
        )
        let group = makeGroup(
            mentors: testCase.mentorChallengerIds.enumerated().map { index, challengerId in
                makeMember(
                    serverID: "\(index)",
                    challengerID: challengerId,
                    role: .leader
                )
            }
        )

        #expect(viewModel.canRegisterSchedule(for: group) == testCase.canRegister)
    }

    /// 낙관적 삽입 placeholder 는 아직 서버 식별자가 없어, 그대로 넘기면 일정 등록 화면이
    /// 존재하지 않는 그룹 ID(`new_…`)를 받는다. 레거시는 `Int` 변환 실패로 막던 자리다.
    @Test("서버 저장 전 placeholder 그룹은 멘토라도 등록할 수 없다")
    func localPlaceholderGroupCannotRegisterSchedule() {
        let useCase = MockOperatorStudyManagementUseCase()
        let viewModel = makeViewModel(useCase: useCase, challengerId: "C-1")
        let group = makeGroup(
            serverID: "new_ABC",
            mentors: [makeMember(serverID: "1", challengerID: "C-1", role: .leader)]
        )

        #expect(viewModel.canRegisterSchedule(for: group) == false)
    }

    @Test("권한이 없으면 안내 다이얼로그를 띄운다")
    func deniedPromptIsPresented() {
        let useCase = MockOperatorStudyManagementUseCase()
        let viewModel = makeViewModel(useCase: useCase)

        viewModel.presentScheduleRegistrationDenied()

        #expect(viewModel.alertPrompt?.title == "권한 없음")
        #expect(viewModel.alertPrompt?.message == "담당 파트장(멘토)만 일정을 등록할 수 있습니다.")
    }
}

// MARK: - 제출 현황 Helpers

private func makeWeek(
    weekNo: String,
    weeklyCurriculumId: String? = nil,
    challengerWorkbookId: String? = "CW-1",
    status: ChallengerWorkbookStatus = .pass
) -> WeeklySubmission {
    WeeklySubmission(
        weekNo: weekNo,
        weeklyCurriculumId: weeklyCurriculumId ?? "WC-\(weekNo)",
        challengerWorkbookId: challengerWorkbookId,
        status: status
    )
}

/// - Parameter partLabel: 표시 전용 라벨 — 본 스위트의 검증 대상과 무관해 고정한다.
private func makeSubmission(
    studyGroupMemberId: String,
    studyGroupId: String = "G-1",
    weeks: [WeeklySubmission] = [makeWeek(weekNo: "1")],
    partLabel: String = "iOS"
) -> StudyMemberSubmission {
    StudyMemberSubmission(
        studyGroupMemberId: studyGroupMemberId,
        memberId: "M-\(studyGroupMemberId)",
        memberName: "챌린저\(studyGroupMemberId)",
        studyGroupId: studyGroupId,
        studyGroupName: "iOS 스터디",
        part: .front(type: .ios),
        partLabel: partLabel,
        weeks: weeks
    )
}

private func makeSubmissionPage(
    content: [StudyMemberSubmission],
    hasNext: Bool = false,
    nextCursor: String? = nil
) -> StudyMemberSubmissionPage {
    StudyMemberSubmissionPage(
        content: content,
        hasNext: hasNext,
        nextCursor: nextCursor
    )
}

// MARK: - 제출 현황 조회

@MainActor
@Suite("OperatorStudyManagementViewModel — 제출 현황 조회 (도메인 규칙)")
struct OperatorStudyManagementSubmissionTests {

    @Test("첫 페이지 조회 — 목록과 커서 상태를 채운다")
    func fetchLoadsFirstPage() async {
        let useCase = MockOperatorStudyManagementUseCase()
        useCase.submissionPages = [
            makeSubmissionPage(
                content: [makeSubmission(studyGroupMemberId: "1")],
                hasNext: true,
                nextCursor: "1"
            )
        ]
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchSubmissions()

        #expect(viewModel.submissions.map(\.studyGroupMemberId) == ["1"])
        if case .loaded = viewModel.submissionsState {} else {
            Issue.record("상태가 .loaded 여야 함 — 실제: \(viewModel.submissionsState)")
        }
        #expect(useCase.submissionCalls.first?.cursor == nil)
    }

    @Test("조회 실패 — 상태가 .failed 로 전이한다")
    func fetchFailurePropagatesToState() async {
        let useCase = MockOperatorStudyManagementUseCase()
        useCase.submissionError = DummyError()
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchSubmissions()

        if case .failed = viewModel.submissionsState {} else {
            Issue.record("상태가 .failed 여야 함 — 실제: \(viewModel.submissionsState)")
        }
    }

    @Test("취소는 실패가 아니므로 이전 상태로 롤백한다")
    func cancellationRollsBackToPreviousState() async {
        let useCase = MockOperatorStudyManagementUseCase()
        useCase.submissionPages = [
            makeSubmissionPage(content: [makeSubmission(studyGroupMemberId: "1")])
        ]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchSubmissions()

        // 두 번째 조회가 취소되면 첫 조회 결과가 그대로 남아야 한다.
        useCase.submissionError = CancellationError()
        await viewModel.selectSubmissionGroup("G-9")

        #expect(viewModel.submissions.map(\.studyGroupMemberId) == ["1"])
        if case .loaded = viewModel.submissionsState {} else {
            Issue.record("취소 후 이전 .loaded 가 유지돼야 함")
        }
    }

    // MARK: - 페이지네이션

    @Test("마지막 카드 도달 시 다음 페이지를 이어 붙인다")
    func loadMoreAppendsNextPage() async {
        let useCase = MockOperatorStudyManagementUseCase()
        useCase.submissionPages = [
            makeSubmissionPage(
                content: [makeSubmission(studyGroupMemberId: "1")],
                hasNext: true,
                nextCursor: "1"
            ),
            makeSubmissionPage(content: [makeSubmission(studyGroupMemberId: "2")])
        ]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchSubmissions()

        await viewModel.loadMoreSubmissionsIfNeeded(currentMemberID: "1")

        #expect(viewModel.submissions.map(\.studyGroupMemberId) == ["1", "2"])
        #expect(useCase.submissionCalls.last?.cursor == "1")
    }

    @Test("마지막 카드가 아니면 다음 페이지를 요청하지 않는다")
    func loadMoreSkipsWhenNotLastCard() async {
        let useCase = MockOperatorStudyManagementUseCase()
        useCase.submissionPages = [
            makeSubmissionPage(
                content: [
                    makeSubmission(studyGroupMemberId: "1"),
                    makeSubmission(studyGroupMemberId: "2")
                ],
                hasNext: true,
                nextCursor: "2"
            )
        ]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchSubmissions()
        let callsAfterFirstPage = useCase.submissionCalls.count

        await viewModel.loadMoreSubmissionsIfNeeded(currentMemberID: "1")

        #expect(useCase.submissionCalls.count == callsAfterFirstPage)
    }

    @Test("중복 스터디원은 다음 페이지에서 걸러진다")
    func loadMoreDeduplicatesRows() async {
        let useCase = MockOperatorStudyManagementUseCase()
        useCase.submissionPages = [
            makeSubmissionPage(
                content: [makeSubmission(studyGroupMemberId: "1")],
                hasNext: true,
                nextCursor: "1"
            ),
            makeSubmissionPage(
                content: [
                    makeSubmission(studyGroupMemberId: "1"),
                    makeSubmission(studyGroupMemberId: "2")
                ]
            )
        ]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchSubmissions()

        await viewModel.loadMoreSubmissionsIfNeeded(currentMemberID: "1")

        #expect(viewModel.submissions.map(\.studyGroupMemberId) == ["1", "2"])
    }

    // MARK: - 필터

    @Test("그룹 필터를 바꾸면 커서 없이 첫 페이지부터 다시 조회한다")
    func groupFilterResetsPagination() async {
        let useCase = MockOperatorStudyManagementUseCase()
        useCase.submissionPages = [
            makeSubmissionPage(
                content: [makeSubmission(studyGroupMemberId: "1")],
                hasNext: true,
                nextCursor: "1"
            ),
            makeSubmissionPage(content: [makeSubmission(studyGroupMemberId: "9")])
        ]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchSubmissions()

        await viewModel.selectSubmissionGroup("G-7")

        let lastCall = useCase.submissionCalls.last
        #expect(lastCall?.studyGroupId == "G-7")
        #expect(lastCall?.cursor == nil)
        #expect(viewModel.submissions.map(\.studyGroupMemberId) == ["9"])
    }

    @Test("같은 그룹을 다시 선택하면 재조회하지 않는다")
    func selectingSameGroupSkipsRefetch() async {
        let useCase = MockOperatorStudyManagementUseCase()
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchSubmissions()
        let callsAfterFirstPage = useCase.submissionCalls.count

        await viewModel.selectSubmissionGroup(nil)

        #expect(useCase.submissionCalls.count == callsAfterFirstPage)
    }

    @Test("주차를 켜면 선택 목록이 요청에 실린다")
    func weekFilterOnForwardsSelection() async {
        let useCase = MockOperatorStudyManagementUseCase()
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchSubmissions()

        await viewModel.toggleSubmissionWeek("2")

        #expect(viewModel.selectedSubmissionWeekNos == ["2"])
        #expect(useCase.submissionCalls.last?.weekNos == ["2"])
    }

    @Test("같은 주차를 다시 누르면 선택이 해제되고 전체 주차로 재조회한다")
    func weekFilterOffClearsSelection() async {
        let useCase = MockOperatorStudyManagementUseCase()
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchSubmissions()
        await viewModel.toggleSubmissionWeek("2")

        await viewModel.toggleSubmissionWeek("2")

        #expect(viewModel.selectedSubmissionWeekNos.isEmpty)
        #expect(useCase.submissionCalls.last?.weekNos == [])
    }

    @Test("주차 후보는 주차 필터가 걸리지 않은 응답에서만 갱신된다")
    func weekOptionsIgnoreFilteredResponse() async {
        let useCase = MockOperatorStudyManagementUseCase()
        useCase.submissionPages = [
            makeSubmissionPage(
                content: [
                    makeSubmission(
                        studyGroupMemberId: "1",
                        weeks: [makeWeek(weekNo: "1"), makeWeek(weekNo: "2")]
                    )
                ]
            ),
            // 주차 필터가 걸린 응답 — 후보를 좁혀 해제 불가가 되면 안 된다.
            makeSubmissionPage(
                content: [
                    makeSubmission(
                        studyGroupMemberId: "1",
                        weeks: [makeWeek(weekNo: "2")]
                    )
                ]
            )
        ]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchSubmissions()

        await viewModel.toggleSubmissionWeek("2")

        #expect(viewModel.availableSubmissionWeekNos == ["1", "2"])
    }

    @Test("주차 후보는 다음 페이지의 주차까지 누적한다")
    func weekOptionsGrowAcrossPages() async {
        let useCase = MockOperatorStudyManagementUseCase()
        useCase.submissionPages = [
            makeSubmissionPage(
                content: [
                    makeSubmission(
                        studyGroupMemberId: "1",
                        weeks: [makeWeek(weekNo: "1")]
                    )
                ],
                hasNext: true,
                nextCursor: "1"
            ),
            makeSubmissionPage(
                content: [
                    makeSubmission(
                        studyGroupMemberId: "2",
                        weeks: [makeWeek(weekNo: "2")]
                    )
                ]
            )
        ]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchSubmissions()
        #expect(viewModel.availableSubmissionWeekNos == ["1"])

        await viewModel.loadMoreSubmissionsIfNeeded(currentMemberID: "1")

        #expect(viewModel.availableSubmissionWeekNos == ["1", "2"])
    }

    @Test("그룹을 바꾸면 이전 그룹의 주차 후보가 남지 않는다")
    func weekOptionsResetOnGroupChange() async {
        let useCase = MockOperatorStudyManagementUseCase()
        useCase.submissionPagesByGroupId = [
            "": makeSubmissionPage(
                content: [
                    makeSubmission(
                        studyGroupMemberId: "1",
                        weeks: [makeWeek(weekNo: "1"), makeWeek(weekNo: "2")]
                    )
                ]
            ),
            "G-7": makeSubmissionPage(
                content: [
                    makeSubmission(
                        studyGroupMemberId: "9",
                        weeks: [makeWeek(weekNo: "3")]
                    )
                ]
            )
        ]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchSubmissions()

        await viewModel.selectSubmissionGroup("G-7")

        #expect(viewModel.availableSubmissionWeekNos == ["3"])
    }

    // MARK: - 필터 ↔ 목록 정합

    @Test("필터 변경이 취소되면 칩 선택도 이전 필터로 되돌아간다")
    func cancelledFilterChangeRevertsSelection() async {
        let useCase = MockOperatorStudyManagementUseCase()
        useCase.submissionPages = [
            makeSubmissionPage(content: [makeSubmission(studyGroupMemberId: "1")])
        ]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchSubmissions()

        useCase.submissionError = CancellationError()
        await viewModel.selectSubmissionGroup("G-7")

        // 목록은 전체 그룹의 결과 그대로이므로 칩도 전체 그룹이어야 한다.
        #expect(viewModel.selectedSubmissionGroupId == nil)
        #expect(viewModel.submissions.map(\.studyGroupMemberId) == ["1"])
    }

    @Test("같은 필터로 재진입하면 로드된 페이지를 버리지 않는다")
    func reentryKeepsLoadedPageWhenFilterMatches() async {
        let useCase = MockOperatorStudyManagementUseCase()
        useCase.submissionPagesByGroupId = [
            "": makeSubmissionPage(content: [makeSubmission(studyGroupMemberId: "1")]),
            "G-7": makeSubmissionPage(content: [makeSubmission(studyGroupMemberId: "9")])
        ]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchSubmissions()
        await viewModel.selectSubmissionGroup("G-7")
        let callsAfterFilter = useCase.submissionCalls.count

        await viewModel.fetchSubmissions()

        #expect(useCase.submissionCalls.count == callsAfterFilter)
        #expect(viewModel.submissions.map(\.studyGroupMemberId) == ["9"])
    }

    @Test("필터 변경이 취소돼도 남은 목록의 페이지네이션은 살아 있다")
    func cancelledFilterChangeKeepsPagination() async {
        let useCase = MockOperatorStudyManagementUseCase()
        // 취소된 호출은 페이지를 소비하지 않으므로, 두 번째 페이지는 추가 로드가 가져간다.
        useCase.submissionPages = [
            makeSubmissionPage(
                content: [makeSubmission(studyGroupMemberId: "1")],
                hasNext: true,
                nextCursor: "1"
            ),
            makeSubmissionPage(content: [makeSubmission(studyGroupMemberId: "2")])
        ]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchSubmissions()

        // 필터 변경이 취소되면 목록은 그대로 남는데, 커서까지 초기화된 채 두면
        // 스크롤해도 다음 페이지를 못 부른다.
        useCase.submissionError = CancellationError()
        await viewModel.selectSubmissionGroup("G-7")

        useCase.submissionError = nil
        await viewModel.loadMoreSubmissionsIfNeeded(currentMemberID: "1")

        #expect(viewModel.submissions.map(\.studyGroupMemberId) == ["1", "2"])
    }

    @Test("목록과 필터가 어긋난 채 재진입하면 건너뛰지 않고 다시 조회한다")
    func reentryRefetchesWhenFilterDoesNotMatchList() async {
        let useCase = MockOperatorStudyManagementUseCase()
        useCase.submissionPagesByGroupId = [
            "": makeSubmissionPage(content: [makeSubmission(studyGroupMemberId: "1")]),
            "G-B": makeSubmissionPage(content: [makeSubmission(studyGroupMemberId: "2")]),
            "G-C": makeSubmissionPage(content: [makeSubmission(studyGroupMemberId: "3")])
        ]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchSubmissions()

        // 필터를 연달아 바꾸고 둘 다 취소시키면, 마지막 요청의 롤백이 목록(전체 그룹)과
        // 어긋나는 중간 필터(G-B)를 복원한다 — 칩과 목록이 다른 조건을 가리키는 상태.
        useCase.gateSubmissions = true
        let toB = Task { await viewModel.selectSubmissionGroup("G-B") }
        await drainUntil { useCase.pendingSubmissionCount == 1 }
        let toC = Task { await viewModel.selectSubmissionGroup("G-C") }
        await drainUntil { useCase.pendingSubmissionCount == 2 }

        useCase.submissionError = CancellationError()
        useCase.releaseSubmissions()
        await toB.value
        await toC.value

        #expect(viewModel.selectedSubmissionGroupId == "G-B")
        #expect(viewModel.submissions.map(\.studyGroupMemberId) == ["1"])

        // 어긋난 상태로 재진입하면 건너뛰지 않고 선택된 필터로 다시 조회해야 한다.
        useCase.submissionError = nil
        useCase.gateSubmissions = false
        await viewModel.fetchSubmissions()

        #expect(viewModel.submissions.map(\.studyGroupMemberId) == ["2"])
    }

    // MARK: - 요청 토큰 (latest-wins)

    @Test("필터 변경 전 요청의 응답은 최신 목록을 덮어쓰지 않는다")
    func staleResponseDoesNotOverwriteLatest() async {
        let useCase = MockOperatorStudyManagementUseCase()
        // 응답을 호출 순서가 아니라 그룹 필터로 고정한다 — 게이트 재개 순서와 무관하게 결정론적.
        useCase.submissionPagesByGroupId = [
            "": makeSubmissionPage(content: [makeSubmission(studyGroupMemberId: "old")]),
            "G-7": makeSubmissionPage(content: [makeSubmission(studyGroupMemberId: "new")])
        ]
        useCase.gateSubmissions = true
        let viewModel = makeViewModel(useCase: useCase)

        // 첫 요청을 붙잡아 둔 상태에서 필터를 바꿔 두 번째 요청을 시작한다.
        let first = Task { await viewModel.fetchSubmissions() }
        await drainUntil { useCase.pendingSubmissionCount == 1 }
        let second = Task { await viewModel.selectSubmissionGroup("G-7") }
        await drainUntil { useCase.pendingSubmissionCount == 2 }

        useCase.releaseSubmissions()
        await first.value
        await second.value

        // 두 응답이 모두 도착해도 최신 필터(G-7)의 결과만 남아야 한다.
        #expect(viewModel.submissions.map(\.studyGroupMemberId) == ["new"])
    }

    // MARK: - 재진입 가드 ↔ 취소 롤백 (stuck loading 방지)

    /// 재진입 플래그가 취소 경로에서도 반드시 해제되는지 고정한다.
    /// (스피너 고착 자체는 아래 `cancelDuringLoadingDoesNotStickInLoading` 이 잡는다.)
    @Test("취소된 조회가 재진입 가드를 붙잡아 두지 않는다")
    func cancelledReloadReleasesReentrancyGuard() async {
        let useCase = MockOperatorStudyManagementUseCase()
        useCase.gateSubmissions = true
        let viewModel = makeViewModel(useCase: useCase)

        // 진행 중인 첫 조회가 아직 응답 전인 동안 두 번째 진입이 들어온다.
        let first = Task { await viewModel.fetchSubmissions() }
        await drainUntil { useCase.pendingSubmissionCount == 1 }
        let blocked = Task { await viewModel.fetchSubmissions() }

        // 첫 조회가 취소로 끝나 이전 상태(.idle)로 되돌아간다.
        useCase.submissionError = CancellationError()
        useCase.releaseSubmissions()
        await first.value
        await blocked.value

        // 상태가 .idle 로 돌아왔어도 in-flight 가 없으므로 재조회가 가능해야 한다.
        useCase.submissionError = nil
        useCase.gateSubmissions = false
        useCase.submissionPages = [
            makeSubmissionPage(content: [makeSubmission(studyGroupMemberId: "1")])
        ]

        await viewModel.fetchSubmissions()

        #expect(viewModel.submissions.map(\.studyGroupMemberId) == ["1"])
    }

    @Test("로딩 중 필터를 눌러 취소돼도 상태가 .loading 에 갇히지 않는다")
    func cancelDuringLoadingDoesNotStickInLoading() async {
        let useCase = MockOperatorStudyManagementUseCase()
        useCase.gateSubmissions = true
        let viewModel = makeViewModel(useCase: useCase)

        // 첫 조회가 .loading 인 상태에서 그룹 칩을 누른다 → 두 번째 조회의 롤백 스냅샷이
        // .loading 이면, 그 조회가 취소될 때 화면이 영구 스피너가 된다.
        let first = Task { await viewModel.fetchSubmissions() }
        await drainUntil { useCase.submissionCalls.count == 1 }
        let second = Task { await viewModel.selectSubmissionGroup("G-7") }
        await drainUntil { useCase.submissionCalls.count == 2 }

        useCase.submissionError = CancellationError()
        useCase.releaseSubmissions()
        await first.value
        await second.value

        #expect(!viewModel.submissionsState.isLoading)
    }

    // MARK: - 추가 로드 실패 (형제 대칭)

    @Test("필터가 바뀐 뒤 도착한 추가 로드 실패는 알림을 띄우지 않는다")
    func staleLoadMoreFailureIsIgnored() async {
        let useCase = MockOperatorStudyManagementUseCase()
        useCase.submissionPages = [
            makeSubmissionPage(
                content: [makeSubmission(studyGroupMemberId: "1")],
                hasNext: true,
                nextCursor: "1"
            )
        ]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchSubmissions()

        // 추가 로드를 게이트로 붙잡아 둔 채 그룹 필터를 바꿔 토큰을 올린다.
        useCase.gateSubmissions = true
        let loadMore = Task {
            await viewModel.loadMoreSubmissionsIfNeeded(currentMemberID: "1")
        }
        await drainUntil { useCase.pendingSubmissionCount == 1 }

        // 이후 호출은 붙잡지 않는다 — 필터 재조회는 정상 완료돼야 토큰이 올라간다.
        useCase.gateSubmissions = false
        await viewModel.selectSubmissionGroup("G-7")

        // 붙잡아 둔 추가 로드만 실패시킨다.
        useCase.submissionError = DomainError.custom(message: "추가 로드 실패")
        useCase.releaseSubmissions()
        await loadMore.value

        #expect(viewModel.alertPrompt == nil)
    }

    @Test("현재 필터의 추가 로드 실패는 알림으로 알린다")
    func currentLoadMoreFailureShowsAlert() async {
        let useCase = MockOperatorStudyManagementUseCase()
        useCase.submissionPages = [
            makeSubmissionPage(
                content: [makeSubmission(studyGroupMemberId: "1")],
                hasNext: true,
                nextCursor: "1"
            )
        ]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchSubmissions()

        useCase.submissionError = DomainError.custom(message: "추가 로드 실패")
        await viewModel.loadMoreSubmissionsIfNeeded(currentMemberID: "1")

        #expect(viewModel.alertPrompt != nil)
    }

    // MARK: - 그룹 필터 후보

    @Test("그룹 이름 목록은 한 번만 조회한다")
    func groupNamesAreFetchedOnce() async {
        let useCase = MockOperatorStudyManagementUseCase()
        useCase.groupNames = [StudyGroupName(groupId: "G-1", name: "iOS A팀")]
        let viewModel = makeViewModel(useCase: useCase)

        // 재시도로 두 번째 조회를 강제해도(진입 스킵 가드 우회) 이름 목록은 다시 부르지 않는다.
        await viewModel.fetchSubmissions()
        await viewModel.retrySubmissions()

        #expect(useCase.groupNamesCallCount == 1)
        #expect(viewModel.studyGroupNames.map(\.groupId) == ["G-1"])
    }

    @Test("그룹 이름 조회 실패는 제출 현황 조회를 막지 않는다")
    func groupNamesFailureDoesNotBlockSubmissions() async {
        let useCase = MockOperatorStudyManagementUseCase()
        useCase.groupNamesError = DummyError()
        useCase.submissionPages = [
            makeSubmissionPage(content: [makeSubmission(studyGroupMemberId: "1")])
        ]
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchSubmissions()

        #expect(viewModel.studyGroupNames.isEmpty)
        #expect(viewModel.submissions.map(\.studyGroupMemberId) == ["1"])
    }
}

#endif
