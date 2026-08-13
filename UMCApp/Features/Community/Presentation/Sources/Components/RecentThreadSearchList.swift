//
//  RecentThreadSearchList.swift
//  CommunityPresentation
//

import SwiftUI
import CoreDesignSystem
import CoreUIComponents

// MARK: - Constants

fileprivate enum Constants {
    static let rowMinHeight: CGFloat = 44
    static let deleteButtonSize: CGFloat = 44
    static let termLineLimit = 1
}

/// 검색 필드를 열었지만 아직 입력이 없을 때 결과 목록 위를 덮는 최근 검색어 목록.
///
/// `\.isSearching` 은 `.searchable` 을 붙인 View 자신에게는 내려오지 않는다. 리스트 화면이
/// 직접 읽을 수 없어 이렇게 하위 View 로 분리한다.
struct RecentThreadSearchList: View {

    // MARK: - Property

    let terms: [String]
    /// 입력이 시작되면 실시간 결과를 가리지 않도록 스스로 물러난다.
    let isQueryEmpty: Bool
    let onSelect: (String) -> Void
    let onDelete: (String) -> Void
    let onClearAll: () -> Void

    @Environment(\.isSearching) private var isSearching

    // MARK: - Body

    var body: some View {
        if isSearching, isQueryEmpty, !terms.isEmpty {
            list
        }
    }

    // MARK: - View Component

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            List {
                ForEach(terms, id: \.self) { term in
                    row(term)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .umcDefaultBackground()
        // 아래 결과 목록이 비쳐 보이지 않도록 불투명 바닥을 깐다.
        .background(.background)
    }

    private var header: some View {
        HStack {
            Text("최근 검색어")
                .appFont(.footnote, weight: .semibold, color: .grey600)

            Spacer()

            Button {
                onClearAll()
            } label: {
                Text("전체 삭제")
                    .appFont(.footnote, color: .grey500)
                    .frame(minHeight: Constants.rowMinHeight)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DefaultSpacing.spacing16)
    }

    /// 검색어 버튼과 삭제 버튼을 따로 둔다 — 행 전체를 버튼으로 만들면 삭제를 누를 수 없다.
    private func row(_ term: String) -> some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Button {
                onSelect(term)
            } label: {
                Label(term, systemImage: "clock.arrow.circlepath")
                    .appFont(.subheadline, color: .grey900)
                    .lineLimit(Constants.termLineLimit)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: Constants.rowMinHeight)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Button {
                onDelete(term)
            } label: {
                Image(systemName: "xmark")
                    .imageScale(.small)
                    .foregroundStyle(Color.grey500)
                    .frame(
                        width: Constants.deleteButtonSize,
                        height: Constants.deleteButtonSize
                    )
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(term) 검색 기록 삭제")
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}
