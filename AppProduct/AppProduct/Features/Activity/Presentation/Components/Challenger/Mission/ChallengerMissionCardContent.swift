//
//  ChallengerMissionCardContent.swift
//  AppProduct
//
//  Created by jaewon Lee on 01/29/26.
//

import SwiftUI

// MARK: - ChallengerMissionCardContent

/// 미션 카드 확장 콘텐츠 (미션 설명, 제출 타입 선택, 링크 입력/제출 버튼)
struct ChallengerMissionCardContent: View, Equatable {

    // MARK: - Property

    let model: MissionCardModel
    let submissionType: MissionSubmissionType
    let linkText: String
    var focusedMissionID: FocusState<UUID?>.Binding
    let onSubmissionTypeChanged: (MissionSubmissionType) -> Void
    let onLinkTextChanged: (String) -> Void
    let onSubmit: (MissionSubmissionType, String?) -> Void

    static func == (lhs: ChallengerMissionCardContent, rhs: ChallengerMissionCardContent) -> Bool {
        lhs.model == rhs.model &&
        lhs.submissionType == rhs.submissionType &&
        lhs.linkText == rhs.linkText
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing16) {
            switch model.status {
            case .notStarted, .inProgress:
                typeSelectionSection
                submissionView
            case .pendingApproval, .pass, .fail:
                missionTitleText
                statusResultView
            case .locked:
                EmptyView()
            }
        }
    }

    // MARK: - Private Views

    private var missionTitleText: some View {
        Text(model.missionTitle)
            .appFont(.subheadline, color: .gray)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var statusResultView: some View {
        switch model.status {
        case .pendingApproval:
            pendingApprovalView
        case .pass:
            passView
        case .fail:
            failView
        default:
            EmptyView()
        }
    }

    private var submissionView: some View {
        MissionSubmissionView(
            missionID: model.id,
            submissionType: submissionType,
            availableSubmissionTypes: model.missionType.availableSubmissionTypes,
            linkText: linkText,
            focusedMissionID: focusedMissionID,
            onSubmissionTypeChanged: onSubmissionTypeChanged,
            onLinkTextChanged: onLinkTextChanged,
            onSubmit: onSubmit
        )
    }

    private var pendingApprovalView: some View {
        MissionStatusResultView(
            icon: "hourglass",
            message: "확인 대기 중입니다.",
            color: .orange
        )
    }

    private var passView: some View {
        MissionStatusResultView(
            icon: "checkmark.circle.fill",
            message: "미션을 통과하였습니다.",
            color: .green
        )
    }

    private var failView: some View {
        MissionStatusResultView(
            icon: "xmark.circle.fill",
            message: "미션을 통과하지 못했습니다.",
            color: .red
        )
    }
    
    private var typeSelectionSection: some View {
        Group {
            let availableSubmissionTypes = model.missionType.availableSubmissionTypes
            if availableSubmissionTypes.count > 1 {
                Picker(
                    selection: Binding(
                        get: { submissionType },
                        set: { newType in
                            withAnimation(.easeInOut(duration: DefaultConstant.animationTime)) {
                                onSubmissionTypeChanged(newType)
                                if newType == .completeOnly {
                                    onLinkTextChanged("")
                                }
                            }
                        }
                    )
                ) {
                    ForEach(availableSubmissionTypes, id: \.self) { type in
                        Label(type.rawValue, systemImage: type.icon)
                            .tag(type)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

// MARK: - MissionSubmissionView

/// 미션 제출 UI (타입 선택 + 링크 입력 + 제출 버튼)
fileprivate struct MissionSubmissionView: View, Equatable {

    // MARK: - Property

    let missionID: UUID
    let submissionType: MissionSubmissionType
    let availableSubmissionTypes: [MissionSubmissionType]
    let linkText: String
    var focusedMissionID: FocusState<UUID?>.Binding
    let onSubmissionTypeChanged: (MissionSubmissionType) -> Void
    let onLinkTextChanged: (String) -> Void
    let onSubmit: (MissionSubmissionType, String?) -> Void

    // MARK: - Equatable

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.missionID == rhs.missionID &&
        lhs.submissionType == rhs.submissionType &&
        lhs.availableSubmissionTypes == rhs.availableSubmissionTypes &&
        lhs.linkText == rhs.linkText
    }

    // MARK: - Constants

    private enum Constants {
        static let submitButtonWidth: CGFloat = 80
        static let borderWidth: CGFloat = 1
    }

    // MARK: - Computed Property

    private var hasError: Bool {
        !linkText.isEmpty && !linkText.isValidHTTPURL
    }

    private var isSubmitDisabled: Bool {
        guard availableSubmissionTypes.contains(submissionType) else {
            return true
        }
        return submissionType == .link && !linkText.isValidHTTPURL
    }

    // MARK: - Body

    var body: some View {
        submissionSection
    }

    // MARK: - View Components

    private var submissionSection: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            if submissionType == .link {
                linkInput
            }
            
            if submissionType == .link && hasError {
                Text("올바른 URL 형식이 아닙니다")
                    .appFont(.footnote, color: .red)
                    .transition(.opacity)
            }

            SubmitButton(
                isDisabled: isSubmitDisabled,
                onSubmit: {
                    if submissionType == .link {
                        onSubmit(.link, linkText)
                    } else {
                        onSubmit(.completeOnly, nil)
                    }
                }
            )
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: submissionType)
    }

    private var linkInput: some View {
        TextField("", text: Binding(
            get: { linkText },
            set: { onLinkTextChanged($0) }),
                  prompt: textfieldPlaceholder)
        .focused(focusedMissionID, equals: missionID)
        .padding(DefaultConstant.defaultTextFieldPadding)
        .overlay(content: {
            RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius)
                .fill(.clear)
                .strokeBorder(.grey300, style: .init())
        })
        .transition(
            .asymmetric(
                insertion: .scale(scale: 0.95).combined(with: .opacity),
                removal: .scale(scale: 0.95).combined(with: .opacity)
            )
        )
    }
    
    private var textfieldPlaceholder: Text {
        Text("https://...")
            .font(.app(.footnote))
            .foregroundStyle(Color(.placeholderText))
    }
}

// MARK: - MissionStatusResultView

/// 미션 상태 결과 뷰 (아이콘 + 메시지 + 배경)
fileprivate struct MissionStatusResultView: View, Equatable {

    // MARK: - Property

    let icon: String
    let message: String
    let color: Color

    private enum Constants {

        static let backgroundOpacity: Double = 0.15
    }

    // MARK: - Body

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(message)
                .appFont(.callout, color: color)
        }
        .padding(ActivityConstants.statusCardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            color.opacity(Constants.backgroundOpacity),
            in: RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius)
        )
    }
}

// MARK: - SubmitButton

/// 미션 제출 버튼 (공통 스타일)
fileprivate struct SubmitButton: View, Equatable {

    // MARK: - Property

    let isDisabled: Bool
    let onSubmit: () -> Void

    // MARK: - Equatable

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.isDisabled == rhs.isDisabled
    }

    // MARK: - Body

    var body: some View {
        MainButton("제출") {
            onSubmit()
        }
        .buttonStyle(.glassProminent)
        .disabled(isDisabled)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("ChallengerMissionCardContent - InProgress", traits: .sizeThatFitsLayout) {
    struct Demo: View {
        @State private var submissionType: MissionSubmissionType = .link
        @State private var linkText: String = ""
        @FocusState private var focusedMissionID: UUID?

        var body: some View {
            ZStack {
                Color.grey100.ignoresSafeArea().frame(height: 400)

                ChallengerMissionCardContent(
                    model: MissionPreviewData.singleMission,
                    submissionType: submissionType,
                    linkText: linkText,
                    focusedMissionID: $focusedMissionID,
                    onSubmissionTypeChanged: { submissionType = $0 },
                    onLinkTextChanged: { linkText = $0 },
                    onSubmit: { type, link in
                        print("제출: \(type) - \(link ?? "없음")")
                    }
                )
                .glass()
            }
        }
    }

    return Demo()
}

#Preview("ChallengerMissionCardContent - All Status") {
    struct Demo: View {
        @FocusState private var focusedMissionID: UUID?

        var body: some View {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(MissionPreviewData.allStatusMissions) { model in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(model.status.displayText)
                                .appFont(.title3, color: .gray)
                            ChallengerMissionCardContent(
                                model: model,
                                submissionType: .link,
                                linkText: "",
                                focusedMissionID: $focusedMissionID,
                                onSubmissionTypeChanged: { _ in },
                                onLinkTextChanged: { _ in },
                                onSubmit: { _, _ in }
                            )
                            .padding()
                            .background(Color.grey000)
                            .clipShape(RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius))
                        }
                    }
                }
                .padding()
            }
            .background(Color.grey100)
        }
    }
    return Demo()
}
#endif
