//
//  ThreadCategorySheet.swift
//  CommunityPresentation
//

import SwiftUI
import CommunityDomain
import CoreDesignSystem

// MARK: - Constants

fileprivate enum Constants {
    /// 최소 터치 타깃 (접근성 명세 SECTION 07).
    static let rowMinHeight: CGFloat = 44
    static let recommendationBadge = "AI 추천"
}

/// 카테고리 택1 시트.
///
/// 선택 상태(파랑)와 추천 배지(회색)를 다른 채도로 갈라 둔다 — 둘 다 강조색이면 "추천" 이
/// "선택됨" 으로 읽힌다.
struct ThreadCategorySheet: View {

    // MARK: - Property

    @Binding var selection: CommunityThreadCategory

    /// 온디바이스 분류가 제안한 카테고리. 분류기는 후속 작업이라 지금은 항상 `nil` 이고,
    /// 배지도 그리지 않는다. 분류기가 붙으면 이 값만 채우면 된다.
    let recommended: CommunityThreadCategory?

    @Environment(\.dismiss) private var dismiss

    // MARK: - Init

    init(selection: Binding<CommunityThreadCategory>, recommended: CommunityThreadCategory? = nil) {
        self._selection = selection
        self.recommended = recommended
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List(CommunityThreadCategory.allCases, id: \.self) { category in
                Button {
                    selection = category
                    dismiss()
                } label: {
                    row(category)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .navigationTitle("카테고리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - View Component

    private func row(_ category: CommunityThreadCategory) -> some View {
        let isSelected = category == selection

        return HStack(spacing: DefaultSpacing.spacing12) {
            Text(category.defaultIcon)
                .appFont(.title3)

            Text(category.displayName)
                .appFont(.body, weight: isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? Color.indigo500 : Color.grey900)

            if category == recommended {
                recommendationBadge
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.indigo500)
            }
        }
        .frame(minHeight: Constants.rowMinHeight)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// 정보 배지 — 누를 수 없으므로 회색으로 두고 강조색을 쓰지 않는다.
    private var recommendationBadge: some View {
        Text(Constants.recommendationBadge)
            .appFont(.caption1, color: Color.grey600)
            .padding(.horizontal, DefaultSpacing.spacing8)
            .padding(.vertical, DefaultSpacing.spacing4)
            .background(Color.grey100, in: .capsule)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("추천 없음") {
    @Previewable @State var selection: CommunityThreadCategory = .study
    ThreadCategorySheet(selection: $selection)
}

#Preview("추천 배지") {
    @Previewable @State var selection: CommunityThreadCategory = .study
    ThreadCategorySheet(selection: $selection, recommended: .qna)
}
#endif
