//
//  TagListView.swift
//  HomePresentation
//
//  Created by euijjang97 on 1/23/26.
//

import CoreDesignSystem
import CoreUIComponents
import SwiftUI
import UMCFoundation

/// 일정 태그를 고르는 시트
struct TagListView: View {

    // MARK: - Property

    @Binding var tagList: [ScheduleIconCategory]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                ForEach(ScheduleIconCategory.selectableCases, id: \.self) { category in
                    TagRow(
                        category: category,
                        isSelected: tagList.contains(category),
                        tap: { toggleSelection(category) }
                    )
                    .equatable()
                }
            }
            .navigation(naviTitle: NavigationTitle.Shared.tag, displayMode: .inline)
            .toolbar {
                ToolBarCollection.CancelBtn(action: { tagList.removeAll() })

                ToolBarCollection.ConfirmBtn(action: {})
            }
        }
    }

    // MARK: - Function

    private func toggleSelection(_ category: ScheduleIconCategory) {
        if let index = tagList.firstIndex(of: category) {
            tagList.remove(at: index)
        } else {
            tagList.append(category)
        }
    }
}

// MARK: - TagRow

/// 태그 한 줄. 선택 상태만 바뀌면 다시 그리도록 `Equatable` 로 비교한다.
private struct TagRow: View, Equatable {

    // MARK: - Property

    let category: ScheduleIconCategory
    let isSelected: Bool
    let tap: () -> Void

    private enum Constants {
        static let iconSize: CGFloat = 40
        static let checkMark = "checkmark.circle.fill"
        static let circle = "circle"
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.category == rhs.category && lhs.isSelected == rhs.isSelected
    }

    // MARK: - Body

    var body: some View {
        Button(action: tap) {
            HStack(spacing: DefaultSpacing.spacing12) {
                Image(systemName: category.symbol)
                    .font(.body)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Constants.iconSize, height: Constants.iconSize)
                    .foregroundStyle(.white)
                    .clipShape(.circle)
                    .glassEffect(.clear.tint(category.color), in: .circle)

                Text(category.korean)
                    .appFont(.body, color: Color.grey900)

                Spacer()

                Image(systemName: isSelected ? Constants.checkMark : Constants.circle)
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.indigo500 : Color.grey300)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview {
    @Previewable @State var tagList: [ScheduleIconCategory] = []

    TagListView(tagList: $tagList)
}
#endif
