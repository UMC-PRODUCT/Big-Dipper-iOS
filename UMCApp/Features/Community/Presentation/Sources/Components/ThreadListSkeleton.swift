//
//  ThreadListSkeleton.swift
//  CommunityPresentation
//

import SwiftUI
import CoreDesignSystem

// MARK: - Constants

fileprivate enum Constants {
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
/// 중앙 스피너 대신 쓰는 이유는 로드가 끝나는 순간의 화면 튐을 줄이기 위해서다. 카드 크롬(여백·
/// 배경·그림자·행 인셋)과 아바타 지름을 ``ThreadCardMetrics`` 로 ``ThreadListRow`` 와 공유하므로
/// 실제 행으로 바뀔 때 배경·구분선·아바타 모양·행 높이가 모두 그대로다.
struct ThreadListSkeleton: View {

    // MARK: - Property

    @ScaledMetric(relativeTo: .title2) private var scaledIconSize = ThreadCardMetrics.iconSize

    // MARK: - Body

    var body: some View {
        List(Constants.previewTrailingInsets, id: \.self) { previewInset in
            row(previewTrailingInset: previewInset)
                .threadCardRow()
        }
        .listStyle(.plain)
        // 행이 카드라서 리스트가 흰 배경을 깔면 카드 경계가 사라진다. 뒤의 연회색은
        // 화면 배경(`umcDefaultBackground`)이 낸다.
        .scrollContentBackground(.hidden)
        // 뼈대는 읽어 줄 내용이 없다. 빈 줄 여섯 개 대신 상태 한 줄만 읽힌다.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Constants.loadingLabel)
    }

    // MARK: - View Component

    private func row(previewTrailingInset: CGFloat) -> some View {
        HStack(alignment: .top, spacing: DefaultSpacing.spacing12) {
            Circle()
                .fill(Color.grey100)
                .frame(
                    width: min(scaledIconSize, ThreadCardMetrics.maxIconSize),
                    height: min(scaledIconSize, ThreadCardMetrics.maxIconSize)
                )

            VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                ShimmerBar(
                    trailingInset: Constants.titleTrailingInset,
                    height: Constants.titleBarHeight
                )
                ShimmerBar(trailingInset: previewTrailingInset)
            }
            // 뼈대 줄은 14pt 캡슐이라 실제 텍스트의 첫 baseline 보다 살짝 높게 뜬다. 카드
            // 크롬과 무관한 보정이라 ``ThreadCardMetrics`` 로 올리지 않는다.
            .padding(.top, DefaultSpacing.spacing4)
        }
        .threadCard()
    }
}
