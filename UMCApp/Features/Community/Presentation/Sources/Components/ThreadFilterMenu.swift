//
//  ThreadFilterMenu.swift
//  CommunityPresentation
//

import SwiftUI
import CommunityDomain
import CoreDesignSystem

// MARK: - Constants

fileprivate enum Constants {
    static let statusSectionTitle = "상태"
    static let categorySectionTitle = "카테고리"
    static let menuAccessibilityLabel = "스레드 필터"
    static let menuImage = "line.3.horizontal.decrease.circle"
}

/// 우상단 필터 메뉴. 서버 `filter` 파라미터와 1:1 로 대응한다.
///
/// `전체`/`안읽음` 과 카테고리 4종 사이에 구분선을 둬 성격이 다른 축임을 드러낸다. 한 `Picker`
/// 를 쪼개는 대신 축마다 `Picker` 를 두고 같은 selection 에 묶는다 — 선택된 항목이 없는 쪽은
/// 체크마크만 비고, 두 묶음이 메뉴에서 별개 섹션으로 그려진다.
struct ThreadFilterMenu: View {

    // MARK: - Property

    @Binding var selection: CommunityThreadFilter

    // MARK: - Body

    var body: some View {
        Menu {
            picker(Constants.statusSectionTitle, items: CommunityThreadFilter.statusItems)

            Divider()

            picker(Constants.categorySectionTitle, items: CommunityThreadFilter.categoryItems)
        } label: {
            Image(systemName: Constants.menuImage)
                .foregroundStyle(Color.grey900)
        }
        .accessibilityLabel(Constants.menuAccessibilityLabel)
    }

    // MARK: - View Component

    private func picker(_ title: String, items: [CommunityThreadFilter]) -> some View {
        Picker(title, selection: $selection) {
            ForEach(items, id: \.self) { item in
                row(item)
            }
        }
        .pickerStyle(.inline)
    }

    /// 태그는 분기 안쪽에서 붙인다 — 조건부 뷰 바깥에 붙이면 선택이 통째로 풀린다.
    @ViewBuilder
    private func row(_ item: CommunityThreadFilter) -> some View {
        if let symbolName = item.symbolName {
            Label(item.displayName, systemImage: symbolName).tag(item)
        } else {
            Text(item.displayName).tag(item)
        }
    }
}
