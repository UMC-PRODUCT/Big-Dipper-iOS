//
//  PointGrantFormSheet.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/25/26.
//

import CoreDesignSystem
import CoreUIComponents
import SwiftUI
import UMCFoundation

/// 상벌점 부여 폼 시트
///
/// 포인트 타입 선택 → 배점 입력(CUSTOM 타입만) → 사유 입력 순서로 진행합니다.
/// `viewModel.grantPoint`를 통해 부여 결과를 `OperatorMemberDetailSheetViewModel`과 공유합니다.
struct PointGrantFormSheet: View {

    // MARK: - Property

    let availablePointTypes: [ChallengerPointType]
    let isSubmittingPoint: Bool

    /// 상벌점 부여 결과를 공유하는 ViewModel
    ///
    /// 상세 시트가 소유한 인스턴스를 그대로 참조합니다(폼이 소유하지 않음).
    let viewModel: OperatorMemberDetailSheetViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPointType: ChallengerPointType?
    @State private var customPointValueText: String = ""
    @State private var pointValue: Int = 0
    @State private var pointReason: String = ""
    @State private var showReasonAlert: Bool = false

    // MARK: - Constants

    private enum Constants {
        static let customValueFieldWidth: CGFloat = 100
        static let selectionAnimationDuration: TimeInterval = 0.2
    }

    // MARK: - Computed Property

    private var rewardTypes: [ChallengerPointType] {
        availablePointTypes.filter { $0.isReward }
    }

    private var penaltyTypes: [ChallengerPointType] {
        availablePointTypes.filter { !$0.isReward }
    }

    /// CUSTOM 타입일 때 입력된 배점 유효성 검증. 0점 부여는 허용하지 않습니다.
    private var isCustomPointValueValid: Bool {
        guard selectedPointType?.isCustom == true else { return true }
        return Int(customPointValueText).map { $0 != 0 } ?? false
    }

    /// 확인 버튼 활성화 조건
    private var isConfirmEnabled: Bool {
        selectedPointType != nil && isCustomPointValueValid && !isSubmittingPoint
    }

    private var isReasonBlank: Bool {
        pointReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

                if selectedPointType?.isCustom == true {
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
            } message: {
                if let selected = selectedPointType {
                    Text(reasonAlertMessage(for: selected))
                }
            }
        }
        // 레거시 .fullScreenCover 는 스와이프 dismiss 경로가 구조적으로 없었다. .sheet 로 바꾸면서
        // 그 보증이 사라지므로 부모 상세 시트와 동일하게 막는다(취소 버튼으로만 종료).
        // 동작하지 않는 제스처를 광고하지 않도록 드래그 인디케이터도 노출하지 않는다.
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled()
    }

    // MARK: - SubView

    /// Custom 타입 선택 시 나타나는 배점 직접 입력 섹션
    private var customPointValueSection: some View {
        Section("배점") {
            HStack {
                Text("점수 입력")
                    .appFont(.subheadline)

                Spacer()

                TextField("예: 3 또는 -2", text: $customPointValueText)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .frame(width: Constants.customValueFieldWidth)
                    .onChange(of: customPointValueText) { _, newValue in
                        if let parsed = Int(newValue) { pointValue = parsed }
                    }
            }
        }
    }

    // MARK: - Function

    /// 포인트 부여를 요청하고, 성공 시 시트를 닫고 입력값을 초기화합니다.
    ///
    /// alert 의 확인 버튼은 `disabled` 를 적용해도 시스템이 무시하므로, 빈 사유 방어는
    /// 이 가드가 담당합니다.
    @MainActor
    private func submitPoint() async {
        guard let type = selectedPointType, !isReasonBlank else { return }

        let success = await viewModel.grantPoint(
            type: type,
            value: pointValue,
            reason: pointReason
        )
        guard success else { return }

        dismiss()
        selectedPointType = nil
        customPointValueText = ""
        pointReason = ""
    }

    private func reasonAlertMessage(for type: ChallengerPointType) -> String {
        let sign = pointValue > 0 ? "+" : ""
        return "\(type.displayName) (\(sign)\(pointValue)점) 사유를 입력해주세요."
    }

    /// 포인트 타입 선택 행. 선택 시 체크마크 표시 및 배점 자동 설정.
    private func pointTypeRow(type: ChallengerPointType, tint: Color) -> some View {
        let isSelected = selectedPointType == type

        return Button {
            // 이미 선택된 행 재탭은 무시한다. 재탭을 그대로 처리하면 CUSTOM 행에서
            // 입력해 둔 배점(customPointValueText)이 경고 없이 초기화된다.
            guard selectedPointType != type else { return }

            withAnimation(.easeInOut(duration: Constants.selectionAnimationDuration)) {
                selectedPointType = type
                pointValue = type.isCustom ? 0 : type.defaultPointValue
                if type.isCustom { customPointValueText = "" }
            }
        } label: {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? tint : .grey400)
                    .contentTransition(.symbolEffect(.replace))

                Text(type.displayName)
                    .appFont(.subheadline, color: .primary)

                Spacer()

                if !type.isCustom {
                    Text("\(type.defaultPointValue > 0 ? "+" : "")\(type.defaultPointValue)")
                        .appFont(
                            .subheadline,
                            weight: .semibold,
                            color: isSelected ? tint : .grey500
                        )
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    Text("Preview")
        .sheet(isPresented: .constant(true)) {
            PointGrantFormSheet(
                availablePointTypes: ChallengerPointType.availableTypes(for: 30),
                isSubmittingPoint: false,
                viewModel: OperatorMemberDetailSheetViewModel(
                    onGrantPoint: { _, _, _ in true },
                    onDeletePoint: { _ in nil }
                )
            )
        }
}
#endif
