//
//  RecentThreadSearchList.swift
//  CommunityPresentation
//

import SwiftUI
import CoreDesignSystem
import CoreUIComponents

// MARK: - Constants

fileprivate enum Constants {
    static let minTouchTarget: CGFloat = 44
    static let termMaxWidth: CGFloat = 180
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
    /// Dynamic Type 를 키우면 잘리는 지점도 같이 밀려나야 글자가 덜 잘린다.
    @ScaledMetric(relativeTo: .subheadline)
    private var termMaxWidth: CGFloat = Constants.termMaxWidth
    @State private var availableWidth: CGFloat = .zero

    /// FlowLayout 이 받은 실제 폭에서 칩 크롬(leading 패딩 + 삭제 버튼)을 뺀 만큼이 텍스트가 쓸 수
    /// 있는 최대치다. `@ScaledMetric` 상한만 믿으면 접근성 글자 크기에서 칩이 컨테이너를 넘어
    /// 삭제 버튼이 잘려 나간다.
    private var termWidthCap: CGFloat {
        guard availableWidth > 0 else { return termMaxWidth }

        let chrome = DefaultSpacing.spacing16 + Constants.minTouchTarget
        return min(termMaxWidth, max(.zero, availableWidth - chrome))
    }

    // MARK: - Body

    var body: some View {
        if isSearching, isQueryEmpty, !terms.isEmpty {
            list
        }
    }

    // MARK: - View Component

    private var list: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            header

            ScrollView {
                FlowLayout(spacing: DefaultSpacing.spacing8) {
                    ForEach(terms, id: \.self) { term in
                        chip(term)
                    }
                }
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.width
                } action: { newWidth in
                    availableWidth = newWidth
                }
                // 칩 하나가 빠지면 뒤쪽 칩이 전부 재배치되므로 점프하지 않게 붙인다.
                .animation(.snappy, value: terms)
                // FlowLayout 은 제안된 폭을 그대로 돌려주므로 좌측 정렬은 바깥에서 잡아 준다.
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DefaultSpacing.spacing16)
                .padding(.vertical, DefaultSpacing.spacing8)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
        .umcDefaultBackground()
        // 아래 결과 목록이 비쳐 보이지 않도록 불투명 바닥을 깐다.
        .background(.background)
    }

    private var header: some View {
        HStack {
            Text("최근 검색")
                .appFont(.footnote, weight: .semibold, color: .grey600)

            Spacer()

            Button {
                onClearAll()
            } label: {
                Text("전체 삭제")
                    .appFont(.footnote, color: .grey500)
                    .frame(minHeight: Constants.minTouchTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DefaultSpacing.spacing16)
    }

    /// 검색어 버튼과 삭제 버튼을 따로 둔다 — 칩 전체를 버튼으로 만들면 삭제를 누를 수 없다.
    ///
    /// 두 버튼 모두 캡슐 높이를 가득 채워 최소 터치 타깃을 칩 안에서 확보한다. hit area 를 칩 밖으로
    /// 넓히면 FlowLayout 간격이 좁아 이웃 칩의 터치와 겹친다.
    private func chip(_ term: String) -> some View {
        HStack(spacing: 0) {
            Button {
                onSelect(term)
            } label: {
                Text(term)
                    .appFont(.subheadline, color: .grey900)
                    .lineLimit(Constants.termLineLimit)
                    .truncationMode(.tail)
                    .frame(maxWidth: termWidthCap, alignment: .leading)
                    .padding(.leading, DefaultSpacing.spacing16)
                    .frame(minHeight: Constants.minTouchTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("이 검색어로 다시 검색해요")

            Button {
                onDelete(term)
            } label: {
                Image(systemName: "xmark")
                    .imageScale(.small)
                    .foregroundStyle(Color.grey600)
                    .frame(
                        width: Constants.minTouchTarget,
                        height: Constants.minTouchTarget
                    )
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(term) 검색 기록 삭제")
        }
        .background(Color.grey200, in: .capsule)
    }
}
