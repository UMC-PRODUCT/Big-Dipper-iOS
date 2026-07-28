//
//  OperatorStudyPreviewSupport.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/20/26.
//

#if DEBUG
import ActivityDomain
import CoreDomain
import Foundation
import UMCFoundation

// MARK: - Preview UseCase

/// 프리뷰 전용 스텁 UseCase — 주입된 결과로 조회를 흉내내고, 변경 액션은 no-op.
final class PreviewOperatorStudyManagementUseCase: OperatorStudyManagementUseCaseProtocol {

    /// 조회 시나리오 — 성공(지정 페이지) 또는 실패(지정 에러).
    enum Outcome {
        case page(StudyGroupDetailsPage)
        case failure(Error)
    }

    private let outcome: Outcome

    init(outcome: Outcome = .page(OperatorStudyPreviewData.loadedPage)) {
        self.outcome = outcome
    }

    func fetchStudyGroupDetailsPage(
        cursor: String?,
        size: Int
    ) async throws -> StudyGroupDetailsPage {
        switch outcome {
        case .page(let page):
            return page
        case .failure(let error):
            throw error
        }
    }

    func resolveChallengerId(
        memberId: String,
        preferredGeneration: String?
    ) async throws -> String? { nil }

    func createStudyGroup(
        gisuId: String,
        name: String,
        part: UMCPartType,
        memberIds: [String],
        mentorIds: [String]
    ) async throws {}

    func updateStudyGroup(groupId: String, name: String) async throws {}
    func deleteStudyGroup(groupId: String) async throws {}
    func addStudyGroupMember(groupId: String, memberId: String) async throws {}
    func removeStudyGroupMember(groupId: String, memberId: String) async throws {}
    func addStudyGroupMentor(groupId: String, mentorId: String) async throws {}
    func removeStudyGroupMentor(groupId: String, mentorId: String) async throws {}
}

/// 프리뷰에서 조회 실패 상태(에러 뷰)를 재현하기 위한 샘플 에러.
enum PreviewSampleError: Error {
    case failed
}

// MARK: - Preview Data

/// 프리뷰 공용 샘플 데이터.
enum OperatorStudyPreviewData {

    static let mentor = StudyGroupMember(
        serverID: "M-1",
        memberID: "M-1",
        name: "김멘토",
        nickname: "멘토킴",
        university: "한성대학교",
        role: .leader
    )

    static let members: [StudyGroupMember] = [
        // nickname nil → 카드/리더 행의 이름 폴백(displayName) 렌더 경로 확인용.
        StudyGroupMember(
            serverID: "M-2",
            memberID: "M-2",
            name: "박철수",
            nickname: nil,
            university: "한성대학교"
        ),
        StudyGroupMember(
            serverID: "M-3",
            memberID: "M-3",
            name: "이영희",
            nickname: "영희",
            university: "연세대학교",
            role: .member,
            bestWorkbookPoint: 30
        )
    ]

    static let groups: [StudyGroupInfo] = [
        StudyGroupInfo(
            serverID: "G-1",
            name: "iOS 스터디 A팀",
            part: .front(type: .ios),
            createdDate: Date(timeIntervalSince1970: 1_700_000_000),
            mentors: [mentor],
            members: members
        ),
        StudyGroupInfo(
            serverID: "G-2",
            name: "iOS 스터디 B팀",
            part: .front(type: .ios),
            createdDate: Date(timeIntervalSince1970: 1_700_100_000),
            mentors: [mentor],
            members: Array(members.prefix(1))
        )
    ]

    /// 조회 성공(그룹 존재) 페이지.
    static let loadedPage = StudyGroupDetailsPage(
        content: groups,
        hasNext: false,
        nextCursor: nil
    )

    /// 조회 성공이지만 그룹이 없는 페이지(빈 상태·권한 안내 재현용).
    static let emptyPage = StudyGroupDetailsPage(
        content: [],
        hasNext: false,
        nextCursor: nil
    )

    static let challengers: [ChallengerInfo] = [
        ChallengerInfo(
            memberId: "M-2",
            challengerId: "C-2",
            gen: "11",
            name: "박철수",
            nickname: "철수",
            schoolName: "한성대학교",
            profileImage: nil,
            part: .front(type: .ios)
        ),
        ChallengerInfo(
            memberId: "M-3",
            challengerId: "C-3",
            gen: "11",
            name: "이영희",
            nickname: "영희",
            schoolName: "연세대학교",
            profileImage: nil,
            part: .front(type: .ios)
        )
    ]
}

// MARK: - Preview Factories

@MainActor
private func makePreviewViewModel(
    useCase: PreviewOperatorStudyManagementUseCase,
    gisuId: String?
) -> OperatorStudyManagementViewModel {
    OperatorStudyManagementViewModel(
        errorHandler: ErrorHandler(),
        useCase: useCase,
        gisuIdProvider: { gisuId }
    )
}

/// 조회 결과가 샘플 그룹으로 채워지는 프리뷰용 ViewModel.
@MainActor
func previewOperatorStudyManagementViewModel(
    gisuId: String? = "11"
) -> OperatorStudyManagementViewModel {
    makePreviewViewModel(
        useCase: PreviewOperatorStudyManagementUseCase(),
        gisuId: gisuId
    )
}

/// 지정한 조회 결과(빈 목록·조회 실패)로 상태를 재현하는 프리뷰용 ViewModel.
@MainActor
func previewOperatorStudyManagementViewModel(
    outcome: PreviewOperatorStudyManagementUseCase.Outcome,
    gisuId: String? = "11"
) -> OperatorStudyManagementViewModel {
    makePreviewViewModel(
        useCase: PreviewOperatorStudyManagementUseCase(outcome: outcome),
        gisuId: gisuId
    )
}

/// 편집 시트 프리뷰용 — `editingGroup`·`editingName`을 미리 채운 ViewModel.
@MainActor
func previewEditingViewModel() -> OperatorStudyManagementViewModel {
    let viewModel = previewOperatorStudyManagementViewModel()
    let group = OperatorStudyPreviewData.groups.first
    viewModel.editingGroup = group
    viewModel.editingName = group?.name ?? ""
    return viewModel
}

/// 스터디 그룹 생성 권한(교내 회장)을 가진 프리뷰용 세션.
@MainActor
func previewCreateCapableSession() -> UserSessionManager {
    let session = UserSessionManager()
    session.updateRole(.schoolPresident, allRoles: [.schoolPresident])
    return session
}

/// 스터디 그룹 생성 권한이 없는(챌린저) 프리뷰용 세션.
@MainActor
func previewChallengerSession() -> UserSessionManager {
    let session = UserSessionManager()
    session.updateRole(.challenger, allRoles: [.challenger])
    return session
}
#endif
