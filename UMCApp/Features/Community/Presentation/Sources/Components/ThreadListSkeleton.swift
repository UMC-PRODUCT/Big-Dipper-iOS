//
//  ThreadListSkeleton.swift
//  CommunityPresentation
//

import SwiftUI
import CoreDesignSystem

// MARK: - Constants

fileprivate enum Constants {
    static let iconSize: CGFloat = 44
    static let iconCornerRadius: CGFloat = 12
    static let titleBarHeight: CGFloat = 14
    static let titleTrailingInset: CGFloat = DefaultSpacing.spacing128
    /// 줄마다 미리보기 길이를 다르게 줘 목록처럼 보이게 한다. 값의 개수가 곧 뼈대 행 수다.
    static let previewTrailingInsets: [CGFloat] = [
        DefaultSpacing.spacing40,
        DefaultSpacing.spacing96,
        DefaultSpacing.spacing64,
        DefaultSpacing.spacing32,
        DefaultSpacing.spacing112,
        DefaultSpacing.spacing72
    ]
    static let loadingLabel = "스레드를 불러오는 중"
}

/// 첫 로드 동안 실제 행 자리를 잡아 두는 뼈대 목록.
///
/// 중앙 스피너 대신 쓰는 이유는 로드가 끝나는 순간의 화면 튐을 줄이기 위해서다. 아이콘 타일
/// 크기와 줄 간격을 ``ThreadListRow`` 와 맞춰 두면 실제 행으로 바뀔 때 높이가 거의 그대로다.
struct ThreadListSkeleton: View {

    // MARK: - Body

    var body: some View {
        List(Constants.previewTrailingInsets, id: \.self) { previewInset in
            row(previewTrailingInset: previewInset)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        // 뼈대는 읽어 줄 내용이 없다. 빈 줄 여섯 개 대신 상태 한 줄만 읽힌다.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Constants.loadingLabel)
    }

    // MARK: - View Component

    private func row(previewTrailingInset: CGFloat) -> some View {
        HStack(alignment: .top, spacing: DefaultSpacing.spacing12) {
            RoundedRectangle(cornerRadius: Constants.iconCornerRadius)
                .fill(Color.grey100)
                .frame(width: Constants.iconSize, height: Constants.iconSize)

            VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
                ShimmerBar(
                    trailingInset: Constants.titleTrailingInset,
                    height: Constants.titleBarHeight
                )
                ShimmerBar(trailingInset: previewTrailingInset)
            }
            .padding(.top, DefaultSpacing.spacing4)
        }
        .padding(.vertical, DefaultSpacing.spacing8)
    }
}
