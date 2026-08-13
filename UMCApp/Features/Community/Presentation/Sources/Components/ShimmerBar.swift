//
//  ShimmerBar.swift
//  CommunityPresentation
//

import SwiftUI
import CoreDesignSystem

// MARK: - Constants

fileprivate enum Constants {
    static let defaultHeight: CGFloat = 12
    static let duration: Double = 1.1
}

/// 자리만 잡아 주는 뼈대 줄. 그라디언트의 시작·끝점을 옮겨 빛이 흐르는 느낌을 만든다.
///
/// 흔한 방식은 뷰 너비를 알아야 해서 `GeometryReader` 가 붙는데, 여기서는 그 값이 필요 없다.
///
/// 요약 시트(``ThreadSummarySheet``)와 리스트 스켈레톤(``ThreadListSkeleton``)이 함께 쓴다.
struct ShimmerBar: View {

    // MARK: - Property

    /// 오른쪽을 얼마나 비울지. 줄마다 다르게 줘야 실제 문단·목록처럼 보인다.
    let trailingInset: CGFloat

    var height: CGFloat = Constants.defaultHeight

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isAnimating = false

    // MARK: - Body

    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [.grey100, .grey200, .grey100],
                    startPoint: isAnimating ? .init(x: 1, y: 0.5) : .init(x: -1, y: 0.5),
                    endPoint: isAnimating ? .init(x: 2, y: 0.5) : .init(x: 0, y: 0.5)
                )
            )
            .frame(height: height)
            .padding(.trailing, trailingInset)
            // 끝나지 않는 반복 애니메이션이라 모션 민감 사용자에게는 그대로 두면 안 된다.
            // 뼈대 줄 자체는 남긴다 — 자리를 잡아 주는 역할은 움직임과 무관하다.
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .linear(duration: Constants.duration).repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
    }
}
