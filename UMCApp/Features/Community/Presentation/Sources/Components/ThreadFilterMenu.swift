//
//  ThreadFilterMenu.swift
//  CommunityPresentation
//

import SwiftUI
import CommunityDomain
import CoreDesignSystem

/// 우상단 필터 메뉴. 서버 `filter` 파라미터와 1:1 로 대응한다.
///
/// `전체`/`안읽음` 과 카테고리 4종 사이에 구분선을 둬 성격이 다른 축임을 드러낸다.
struct ThreadFilterMenu: View {

    // MARK: - Property

    @Binding var selection: CommunityThreadFilter

    // MARK: - Body

    var body: some View {
        Menu {
            Picker("필터", selection: $selection) {
                ForEach(CommunityThreadFilter.menuItems, id: \.self) { item in
                    Text(item.displayName).tag(item)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundStyle(Color.grey900)
        }
        .accessibilityLabel("스레드 필터")
    }
}
