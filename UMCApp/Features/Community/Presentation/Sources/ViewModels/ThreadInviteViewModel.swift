//
//  ThreadInviteViewModel.swift
//  CommunityPresentation
//

import Foundation
import Observation
import CommunityDomain
import UMCFoundation

/// 초대 시트 상태 기계.
///
/// 검색은 서버가 아니라 여기서 한다 — `/invitable` 이 범위 필터 파라미터 없이 동아리 전체
/// 후보를 한 번에 내려주므로(#1131 결정 3) 매 글자마다 왕복할 이유가 없다.
///
/// 실패는 전역 Alert 이 아니라 시트 안 인라인이다. 고른 사람을 잃지 않고 그 자리에서 다시 누르면
/// 되는 실패라 흐름을 끊지 않는다 (완료 조건 6 · `+Report` 와 같은 결).
@Observable
@MainActor
public final class ThreadInviteViewModel {

    // MARK: - Property

    public private(set) var state: Loadable<ThreadInviteCandidates> = .idle
    public var searchText: String = ""
    /// 초대 요청 상태. `.loaded` 가 실린 값은 실제로 보낸 인원 수다.
    public private(set) var submitState: Loadable<Int> = .idle
    /// 상한에 걸려 선택이 거절된 사유. 다음 조작에서 지운다.
    public private(set) var capacityNotice: String?

    /// 선택은 후보 배열 순서와 무관하게 유지돼야 한다 — 검색어를 바꾸면 화면에서 사라진 사람도
    /// 계속 선택 상태여야 한다.
    private var selectedMemberIds: Set<String> = []

    private let threadId: String
    private let useCase: CommunityThreadInviteUseCaseProtocol

    // MARK: - Init

    public init(threadId: String, useCase: CommunityThreadInviteUseCaseProtocol) {
        self.threadId = threadId
        self.useCase = useCase
    }

    // MARK: - Computed Property

    public var candidates: [ThreadMember] { state.value?.candidates ?? [] }

    /// 이름 부분 일치. `localizedStandardContains` 라 대소문자·발음 구별 부호를 무시한다.
    public var filteredCandidates: [ThreadMember] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return candidates }
        return candidates.filter { $0.name.localizedStandardContains(keyword) }
    }

    /// 선택 칩에 그릴 사람들. 후보 순서(이름순)를 그대로 따라간다.
    public var selectedMembers: [ThreadMember] {
        candidates.filter { selectedMemberIds.contains($0.id) }
    }

    public var selectedCount: Int { selectedMemberIds.count }

    /// 한 번에 고를 수 있는 인원. 남은 정원과 서버 요청 상한 중 작은 쪽이다.
    public var selectionLimit: Int {
        guard let remainingSlots = state.value?.remainingSlots else {
            return Constants.maxInvitePerRequest
        }
        return min(remainingSlots, Constants.maxInvitePerRequest)
    }

    /// 정원이 가득 차 아무도 고를 수 없는 상태. 화면이 목록 대신 사유를 그린다.
    public var isCapacityFull: Bool {
        state.value != nil && selectionLimit == 0
    }

    public var canSubmit: Bool {
        !selectedMemberIds.isEmpty && !submitState.isLoading
    }

    /// 초대에 성공한 인원 수. 화면이 이 값을 보고 시트를 닫고 상위에 알린다.
    public var invitedCount: Int? { submitState.value }

    // MARK: - Function

    public func isSelected(_ member: ThreadMember) -> Bool {
        selectedMemberIds.contains(member.id)
    }

    public func load() async {
        state = .loading
        do {
            state = .loaded(try await useCase.loadCandidates(threadId: threadId))
        } catch {
            // 취소는 시트를 닫은 정상 흐름이다. 에러 화면으로 바꾸면 안 된다.
            guard !(error is CancellationError) else { return }
            state = .failed(AppError.from(error))
        }
    }

    /// 선택 토글. 상한을 넘기는 선택은 받지 않고 사유만 남긴다 (완료 조건 5).
    ///
    /// 해제는 언제나 통과시킨다 — 상한에 걸린 상태에서 해제까지 막으면 빠져나갈 길이 없다.
    public func toggle(_ member: ThreadMember) {
        capacityNotice = nil
        // 지난 실패 문구는 선택을 바꾸는 순간 의미가 없어진다.
        if submitState.error != nil { submitState = .idle }

        if selectedMemberIds.contains(member.id) {
            selectedMemberIds.remove(member.id)
            return
        }

        guard selectedMemberIds.count < selectionLimit else {
            capacityNotice = Self.capacityNotice(limit: selectionLimit)
            return
        }
        selectedMemberIds.insert(member.id)
    }

    /// 초대 전송. 실패해도 선택은 그대로 둔다 — 시트를 다시 채우게 하면 고른 시간을 통째로
    /// 버리게 된다 (완료 조건 6).
    public func invite() async {
        guard canSubmit else { return }

        // 서버가 집합으로 처리하므로 순서는 의미가 없다.
        let memberIds = Array(selectedMemberIds)
        submitState = .loading
        capacityNotice = nil

        do {
            try await useCase.invite(threadId: threadId, memberIds: memberIds)
            submitState = .loaded(memberIds.count)
        } catch {
            submitState = .failed(AppError.from(error))
        }
    }

    // MARK: - Static Function

    static func capacityNotice(limit: Int) -> String {
        guard limit > 0 else { return Constants.capacityFullNotice }
        return "한 번에 \(limit)명까지 선택할 수 있어요."
    }
}

// MARK: - Constants

fileprivate enum Constants {
    /// 서버 `@Size` 상한. 넘겨 보내면 400 이다.
    static let maxInvitePerRequest = 99
    static let capacityFullNotice = "정원이 가득 차 더 초대할 수 없어요."
}
