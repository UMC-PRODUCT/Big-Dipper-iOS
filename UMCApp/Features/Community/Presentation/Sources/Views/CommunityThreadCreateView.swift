//
//  CommunityThreadCreateView.swift
//  CommunityPresentation
//

import SwiftUI
import CommunityDomain
import CoreDesignSystem
import CoreUIComponents

// MARK: - Constants

fileprivate enum Constants {
    static let titlePrompt = "스레드 제목"
    static let descriptionPrompt = "어떤 스레드인지 한 줄로 알려 주세요"
    static let submitTitle = "스레드 만들기"
    /// 이모지 한 칸이 아이콘처럼 보이도록 본문보다 크게 잡는다.
    static let iconFontSize: CGFloat = 34
}

/// 스레드 생성 폼.
///
/// 아이콘은 앱 자체 이모지 그리드를 만들지 않고 iOS 순정 이모지 키보드에 맡긴다. `String`
/// 바인딩 `TextField` 는 adaptive image glyph 를 지원하지 않는다고 시스템에 알리므로
/// Genmoji·Memoji 가 후보로 뜨지 않고, 표준 유니코드 이모지만 들어온다.
struct CommunityThreadCreateView: View {

    // MARK: - Property

    @State private var viewModel: CommunityThreadCreateViewModel

    private let onCreated: (CommunityThread) -> Void

    /// "이모지 변경하기" 가 이모지 키보드를 바로 띄우게 하는 통로.
    @FocusState private var isIconFocused: Bool

    @Environment(\.dismiss) private var dismiss

    // MARK: - Init

    init(
        viewModel: CommunityThreadCreateViewModel,
        onCreated: @escaping (CommunityThread) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onCreated = onCreated
    }

    // MARK: - Body

    var body: some View {
        Form {
            Section("아이콘") {
                iconField
            }

            Section("제목") {
                TextField(
                    "",
                    text: $viewModel.title,
                    prompt: Text(Constants.titlePrompt)
                )
            }

            Section("스레드 특징") {
                TextField(
                    "",
                    text: $viewModel.threadDescription,
                    prompt: Text(Constants.descriptionPrompt),
                    axis: .vertical
                )
            }

            Section {
                ThreadClassificationCard(viewModel: viewModel) { isIconFocused = true }
            }
            // 카드가 자체 배경(Glass)을 그리므로 Form 의 행 배경·여백을 걷어 낸다.
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            Section("카테고리") {
                categoryRow
            }

            if let message = viewModel.submitErrorMessage {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .appFont(.footnote, color: Color.red500)
                }
            }
        }
        .navigationTitle(Constants.submitTitle)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { submitButton }
        .sheet(isPresented: $viewModel.isCategorySheetPresented) {
            ThreadCategorySheet(
                selection: $viewModel.category,
                recommended: viewModel.recommendedCategory
            )
        }
    }

    // MARK: - View Component

    private var iconField: some View {
        TextField(
            "",
            text: $viewModel.icon,
            prompt: Text(viewModel.iconPlaceholder)
        )
        .font(.system(size: Constants.iconFontSize))
        .multilineTextAlignment(.center)
        .focused($isIconFocused)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .submitLabel(.done)
        .accessibilityLabel("스레드 아이콘")
        .accessibilityHint("이모지 키보드에서 이모지 하나를 고르세요. 비워 두면 카테고리 기본 이모지를 씁니다.")
    }

    private var categoryRow: some View {
        Button {
            viewModel.isCategorySheetPresented = true
        } label: {
            LabeledContent(viewModel.category.displayName) {
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundStyle(Color.grey600)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("카테고리")
        .accessibilityValue(viewModel.category.displayName)
    }

    private var submitButton: some View {
        MainButton(Constants.submitTitle) {
            Task {
                guard let thread = await viewModel.submit() else { return }
                onCreated(thread)
                dismiss()
            }
        }
        .buttonSize(.large)
        .buttonStyle(.glassProminent)
        // 전송 중에는 `canSubmit` 이 false 라 비활성으로 잠긴다 —
        // `buttonSize` 와 `loading` 은 함께 체이닝되지 않으므로 스피너는 쓰지 않는다.
        .disabled(!viewModel.canSubmit)
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
        .padding(.vertical, DefaultSpacing.spacing12)
        .background(.bar)
    }
}
