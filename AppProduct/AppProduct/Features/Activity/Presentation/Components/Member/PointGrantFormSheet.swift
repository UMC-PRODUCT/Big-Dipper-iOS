//
//  PointGrantFormSheet.swift
//  AppProduct
//
//  Created by 이예지 on 2/16/26.
//

import SwiftUI

/// 상벌점 부여 폼 시트
///
/// 포인트 타입 선택 → 배점 입력(CUSTOM 타입만) → 사유 입력 순서로 진행합니다.
/// `viewModel.grantPoint`를 통해 부여 결과를 `OperatorMemberDetailSheetViewModel`과 공유합니다.
struct PointGrantFormSheet: View {

    // MARK: - Property

    let availablePointTypes: [ChallengerPointType]
    let isSubmittingPoint: Bool

    /// 상벌점 부여 결과를 공유하는 ViewModel
    let viewModel: OperatorMemberDetailSheetViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPointType: ChallengerPointType?
    @State private var customPointValueText: String = ""
    @State private var pointValue: Int = 0
    @State private var pointReason: String = ""
    @State private var showReasonAlert: Bool = false

    // MARK: - Computed Property

    private var rewardTypes: [ChallengerPointType] { availablePointTypes.filter { $0.isReward } }
    private var penaltyTypes: [ChallengerPointType] { availablePointTypes.filter { !$0.isReward } }

    /// CUSTOM 타입일 때 입력된 배점 유효성 검증
    private var isCustomPointValueValid: Bool {
        guard selectedPointType?.isCustom == true else { return true }
        return Int(customPointValueText).map { $0 != 0 } ?? false
    }

    /// 확인 버튼 활성화 조건
    private var isConfirmEnabled: Bool {
        selectedPointType != nil && isCustomPointValueValid && !isSubmittingPoint
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                if !rewardTypes.isEmpty {
                    Section("상점") {
                        ForEach(rewardTypes) { pointTypeRow(type: $0, tint: .green) }
                    }
                }
                Section("벌점") {
                    ForEach(penaltyTypes) { pointTypeRow(type: $0, tint: .red) }
                }
                if let selected = selectedPointType, selected.isCustom {
                    customPointValueSection
                }
            }
            .navigationTitle("상벌점 부여")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolBarCollection.CancelBtn { dismiss() }
                ToolBarCollection.ConfirmBtn(
                    action: { showReasonAlert = true },
                    disable: !isConfirmEnabled,
                    isLoading: isSubmittingPoint,
                    dismissOnTap: false
                )
            }
            .alert("사유 입력", isPresented: $showReasonAlert) {
                TextField("사유를 입력하세요", text: $pointReason)
                Button("취소", role: .cancel) { pointReason = "" }
                Button("확인") { Task { await submitPoint() } }
                    .disabled(pointReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                if let selected = selectedPointType {
                    Text("\(selected.displayName) (\(pointValue > 0 ? "+" : "")\(pointValue)점) 사유를 입력해주세요.")
                }
            }
        }
    }

    // MARK: - SubView

    /// Custom 타입 선택 시 나타나는 배점 직접 입력 섹션
    private var customPointValueSection: some View {
        Section("배점") {
            HStack {
                Text("점수 입력").appFont(.subheadline)
                Spacer()
                TextField("예: 3 또는 -2", text: $customPointValueText)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                    .onChange(of: customPointValueText) { _, newValue in
                        if let parsed = Int(newValue) { pointValue = parsed }
                    }
            }
        }
    }

    // MARK: - Function

    /// 포인트 부여를 요청하고, 성공 시 시트를 닫고 입력값을 초기화합니다.
    @MainActor
    private func submitPoint() async {
        guard let type = selectedPointType else { return }
        guard !pointReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let success = await viewModel.grantPoint(type: type, value: pointValue, reason: pointReason)
        guard success else { return }

        dismiss()
        selectedPointType = nil
        customPointValueText = ""
        pointReason = ""
    }

    /// 포인트 타입 선택 행. 선택 시 체크마크 표시 및 배점 자동 설정.
    private func pointTypeRow(type: ChallengerPointType, tint: Color) -> some View {
        let isSelected = selectedPointType == type
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPointType = type
                pointValue = type.isCustom ? 0 : type.defaultPointValue
                if type.isCustom { customPointValueText = "" }
            }
        } label: {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? tint : .grey400)
                    .contentTransition(.symbolEffect(.replace))
                Text(type.displayName).appFont(.subheadline, color: .primary)
                Spacer()
                if !type.isCustom {
                    Text("\(type.defaultPointValue > 0 ? "+" : "")\(type.defaultPointValue)")
                        .appFont(.subheadlineEmphasis, color: isSelected ? tint : .grey500)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
