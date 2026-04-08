//
//  OperatorMemberDetailSheetViewModel.swift
//  AppProduct
//
//  Created by 이예지 on 2/16/26.
//

import SwiftUI

/// 운영진 멤버 상세 시트의 상태와 액션을 관리하는 ViewModel
///
/// `OperatorMemberDetailSheetView`와 `PointGrantFormSheet`이 이 ViewModel을 공유합니다.
/// - 상벌점 부여(`grantPoint`) 결과를 히스토리에 즉시 반영합니다.
/// - 삭제(`deletePenalty`) 성공 시 로컬 목록에서도 제거합니다.
@Observable
final class OperatorMemberDetailSheetViewModel {

    // MARK: - Property

    /// 화면에 표시되는 상벌점 히스토리 목록
    private(set) var penaltyHistory: [OperatorMemberPenaltyHistory] = []

    /// 히스토리 기준 벌점 합계 (서버 누적값이 아닌 로컬 집계)
    private(set) var totalPenalty: Double = 0

    /// 히스토리 기준 상점 합계 (서버 누적값이 아닌 로컬 집계)
    private(set) var totalReward: Double = 0

    /// 일시적 안내 메시지 (삭제 실패 등). 2초 후 자동 초기화.
    var transientHistoryMessage: String?

    /// 상벌점 부여 폼 시트 표시 여부
    var showPointForm: Bool = false

    static let animation: Animation = .spring(response: 0.34, dampingFraction: 0.86)

    private var transientHistoryMessageTask: Task<Void, Never>?
    private let onGrantPoint: @Sendable (ChallengerPointType, Int, String) async -> Bool
    private let onDeletePoint: @Sendable (OperatorMemberPenaltyHistory) async -> String?

    // MARK: - Init

    init(
        onGrantPoint: @escaping @Sendable (ChallengerPointType, Int, String) async -> Bool,
        onDeletePoint: @escaping @Sendable (OperatorMemberPenaltyHistory) async -> String?
    ) {
        self.onGrantPoint = onGrantPoint
        self.onDeletePoint = onDeletePoint
    }

    // MARK: - Function

    /// 멤버 데이터가 변경될 때 히스토리·합계를 동기화합니다.
    ///
    /// - Important: 합계는 `member.penalty`(서버 누적값) 대신 `penaltyHistory` 아이템에서 직접 집계합니다.
    ///   히스토리 항목이 없으면 합계가 0이 되어 배지가 표시되지 않습니다.
    func syncState(from member: MemberManagementItem) {
        penaltyHistory = member.penaltyHistory
        totalPenalty = member.penaltyHistory
            .filter { !$0.pointType.isReward }
            .reduce(0) { $0 + $1.penaltyScore }
        totalReward = member.penaltyHistory
            .filter { $0.pointType.isReward }
            .reduce(0) { $0 + $1.penaltyScore }
    }

    /// 상벌점을 부여하고 성공 시 로컬 히스토리·합계를 즉시 업데이트합니다.
    ///
    /// - Returns: API 호출 성공 여부
    @MainActor
    func grantPoint(type: ChallengerPointType, value: Int, reason: String) async -> Bool {
        let success = await onGrantPoint(type, value, reason)
        guard success else { return false }

        // Custom 타입은 value 부호로 상/벌 구분, 그 외는 pointType으로 판단
        let isRewardPoint = type.isCustom ? value > 0 : type.isReward
        let newHistory = OperatorMemberPenaltyHistory(
            date: Date(),
            reason: reason,
            penaltyScore: Double(abs(value)),
            pointType: type
        )
        withAnimation(Self.animation) {
            penaltyHistory.append(newHistory)
            penaltyHistory.sort { $0.date > $1.date }
            if isRewardPoint {
                totalReward += Double(abs(value))
            } else {
                totalPenalty += Double(abs(value))
            }
        }
        return true
    }

    /// 포인트를 삭제하고 로컬 목록·합계를 즉시 업데이트합니다.
    /// 삭제 실패 시 2초간 에러 메시지를 표시합니다.
    ///
    /// - Parameters:
    ///   - history: 삭제할 히스토리 항목
    ///   - canView: 열람 권한 여부. `false`이면 아무 작업도 하지 않습니다.
    @MainActor
    func deletePenalty(_ history: OperatorMemberPenaltyHistory, canView: Bool) async {
        guard canView else { return }

        if let errorMessage = await onDeletePoint(history) {
            showTransientHistoryMessage(errorMessage)
            return
        }

        guard let index = penaltyHistory.firstIndex(where: { $0.id == history.id }) else { return }
        let deletedScore = penaltyHistory[index].penaltyScore
        let isReward = penaltyHistory[index].pointType.isReward

        withAnimation(Self.animation) {
            penaltyHistory.remove(at: index)
            if isReward {
                totalReward -= deletedScore
            } else {
                totalPenalty -= deletedScore
            }
        }
    }

    /// 일시적 안내 메시지를 2초간 표시한 뒤 자동으로 초기화합니다.
    private func showTransientHistoryMessage(_ message: String) {
        transientHistoryMessageTask?.cancel()
        transientHistoryMessage = message
        transientHistoryMessageTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self else { return }
            await MainActor.run {
                self.transientHistoryMessage = nil
                self.transientHistoryMessageTask = nil
            }
        }
    }
}
