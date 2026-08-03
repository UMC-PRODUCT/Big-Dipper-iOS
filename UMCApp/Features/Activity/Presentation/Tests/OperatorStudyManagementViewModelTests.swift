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

#endif
