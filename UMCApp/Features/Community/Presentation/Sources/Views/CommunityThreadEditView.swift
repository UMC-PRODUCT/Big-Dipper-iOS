//
//  CommunityThreadEditView.swift
//  CommunityPresentation
//

import SwiftUI
import CommunityDomain
import CoreDesignSystem
import CoreUIComponents

// MARK: - Constants

fileprivate enum Constants {
    static let navigationTitle = "스레드 편집"
    static let titlePrompt = "스레드 제목"
    static let descriptionPrompt = "어떤 스레드인지 한 줄로 알려 주세요"
    static let submitTitle = "저장"
    static let deleteTitle = "스레드 삭제"
    static let deleteFooter = "삭제하면 대화 내용과 참여자가 모두 사라져요. 되돌릴 수 없어요."
    static let reclassifyNudge = "특징이 바뀌었어요. 다시 분류하면 카테고리와 아이콘을 새로 정해 드려요."

    /// 이모지 한 칸이 아이콘처럼 보이도록 본문보다 크게 잡는다.
    static let iconFontSize: CGFloat = 34
    /// 파괴적 행이 손가락에 충분히 걸리도록 하는 최소 높이 (HIG).
    static let destructiveRowHeight: CGFloat = 44
}

/// 스레드 편집 폼.
///
/// 생성 폼(#1132)과 같은 필드·같은 분류 카드를 쓴다 — 만들 때와 고칠 때의 화면이 다르면
/// 어떤 값이 무엇이었는지 다시 배워야 한다. 편집에만 있는 건 두 가지다: 특징을 고쳤을 때
/// 재분류를 권하는 넛지(#11)와 맨 아래 삭제(#09).
struct CommunityThreadEditView: View {

    // MARK: - Property

    @State private var viewModel: CommunityThreadEditViewModel

    private let onUpdated: (CommunityThread) -> Void

    /// 삭제가 끝났을 때 리스트에 알린다. 실시간 `thread.deleted` 로도 행이 지워지지만,
    /// 그걸 기다리면 되돌아온 리스트에 방금 지운 스레드가 잠깐 남아 있다.
    private let onDeleted: (String) -> Void

    /// "이모지 변경하기" 가 이모지 키보드를 바로 띄우게 하는 통로.
    @FocusState private var isIconFocused: Bool

    @Environment(\.dismiss) private var dismiss

    // MARK: - Init

    init(
        viewModel: CommunityThreadEditViewModel,
        onUpdated: @escaping (CommunityThread) -> Void,
        onDeleted: @escaping (String) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onUpdated = onUpdated
        self.onDeleted = onDeleted
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
                VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
                    if viewModel.isReclassifySuggested {
                        reclassifyNudge
                    }

                    ThreadClassificationCard(viewModel: viewModel) { isIconFocused = true }
                }
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

            deleteSection
        }
        .navigationTitle(Constants.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { submitButton }
        .sheet(isPresented: $viewModel.isCategorySheetPresented) {
            ThreadCategorySheet(
                selection: $viewModel.category,
                recommended: viewModel.recommendedCategory
            )
        }
        .alertPrompt(item: $viewModel.alertPrompt)
        .onChange(of: viewModel.didDelete) { _, didDelete in
            guard didDelete else { return }
            onDeleted(viewModel.original.id)
            dismiss()
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

    /// 특징만 고치면 카테고리는 그대로 남는다(#3). 그게 맞는 동작이지만 사용자는 모르므로,
    /// 다시 분류할 수 있다는 것만 알리고 실행은 아래 카드 버튼에 맡긴다 (#11).
    private var reclassifyNudge: some View {
        Label(Constants.reclassifyNudge, systemImage: "sparkles")
            .appFont(.footnote, color: .indigo700)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DefaultSpacing.spacing12)
            .background(
                Color.indigo100,
                in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius))
            )
            .accessibilityElement(children: .combine)
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

    /// 삭제는 저장 버튼과 멀리 떨어진 맨 아래에, 휴지통 아이콘까지 달아 둔다 — 색만으로
    /// 구분하면 색각 이상·고대비 설정에서 평범한 행과 같아 보인다.
    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                viewModel.confirmDelete()
            } label: {
                Label(Constants.deleteTitle, systemImage: "trash")
                    .frame(
                        maxWidth: .infinity,
                        minHeight: Constants.destructiveRowHeight,
                        alignment: .leading
                    )
            }
        } footer: {
            Text(Constants.deleteFooter)
                .appFont(.caption1, color: .grey600)
        }
    }

    private var submitButton: some View {
        MainButton(Constants.submitTitle) {
            Task {
                guard let thread = await viewModel.submit() else { return }
                onUpdated(thread)
                dismiss()
            }
        }
        .buttonSize(.large)
        .buttonStyle(.glassProminent)
        // 바뀐 게 없거나(#10) 재분류가 도는 동안(#12) `canSubmit` 이 false 라 잠긴다.
        .disabled(!viewModel.canSubmit)
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
        .padding(.vertical, DefaultSpacing.spacing12)
        .background(.bar)
    }
}
