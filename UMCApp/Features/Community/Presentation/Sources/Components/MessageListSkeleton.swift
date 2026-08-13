//
//  MessageListSkeleton.swift
//  CommunityPresentation
//

import SwiftUI
import CoreDesignSystem

// MARK: - Constants

fileprivate enum Constants {
    /// `MessageBubble` 과 같은 값. 뼈대와 실제 버블의 모서리가 다르면 교체 순간이 튄다.
    static let cornerRadius: CGFloat = 16
    static let bubbleHeight: CGFloat = 40
    static let rowSpacing: CGFloat = DefaultSpacing.spacing16
    static let shimmerDuration: Double = 1.1
    static let loadingLabel = "대화를 불러오는 중"
    /// 좌우와 길이를 섞어 실제 대화처럼 보이게 한다. 폭은 `MessageBubble` 의 상한(280pt) 안쪽
    /// 고정값이다 — 비율로 잡으려면 컨테이너 폭을 재야 하는데 뼈대에 그만한 값이 필요 없다.
    static let rows: [SkeletonRow] = [
        SkeletonRow(isMine: false, width: 180),
        SkeletonRow(isMine: true, width: 120),
        SkeletonRow(isMine: false, width: 232),
        SkeletonRow(isMine: true, width: 96),
        SkeletonRow(isMine: false, width: 148)
    ]
}

/// 뼈대 한 줄의 모양. `ForEach` 식별자로 쓰려고 `Hashable` 로 둔다.
private struct SkeletonRow: Hashable {
    let isMine: Bool
    let width: CGFloat
}

/// 첫 로드 동안 채팅방 자리를 잡아 주는 말풍선 뼈대 (스펙 #15).
///
/// 중앙 스피너 대신 쓰는 이유는 교체 순간의 도약을 없애기 위해서다 — 스피너는 화면 한가운데
/// 한 점이라 실제 목록이 들어오면 레이아웃이 통째로 바뀐다.
struct MessageListSkeleton: View {

    // MARK: - Body

    var body: some View {
        VStack(spacing: Constants.rowSpacing) {
            ForEach(Constants.rows, id: \.self) { row in
                SkeletonBubble(row: row)
            }
        }
        .padding(.horizontal, DefaultSpacing.spacing16)
        .padding(.top, DefaultSpacing.spacing16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // 뼈대 줄 하나하나를 읽어 줄 이유가 없다. 지금 무엇을 기다리는지만 알리면 된다.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Constants.loadingLabel)
    }
}

// MARK: - Skeleton Bubble

/// 뼈대 말풍선 한 개.
///
/// 그라디언트의 시작·끝 지점을 애니메이션해 빛이 지나가게 만든다 (`ThreadSummarySheet` 의
/// 뼈대 줄과 같은 방식). 마스크를 오프셋으로 미는 흔한 방식은 뷰 너비를 알아야 해서
/// `GeometryReader` 가 붙는데, 여기서는 그 값이 필요 없다.
private struct SkeletonBubble: View {

    // MARK: - Property

    let row: SkeletonRow

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isAnimating = false

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            if row.isMine {
                Spacer(minLength: DefaultSpacing.spacing32)
            }

            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [.grey100, .grey200, .grey100],
                        startPoint: isAnimating ? .init(x: 1, y: 0.5) : .init(x: -1, y: 0.5),
                        endPoint: isAnimating ? .init(x: 2, y: 0.5) : .init(x: 0, y: 0.5)
                    )
                )
                .frame(width: row.width, height: Constants.bubbleHeight)

            if !row.isMine {
                Spacer(minLength: DefaultSpacing.spacing32)
            }
        }
        // 끝나지 않는 반복 애니메이션이라 모션 민감 사용자에게는 그대로 두면 안 된다.
        // 뼈대 자체는 남긴다 — 자리를 잡아 주는 역할은 움직임과 무관하다.
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(
                .linear(duration: Constants.shimmerDuration).repeatForever(autoreverses: false)
            ) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    MessageListSkeleton()
}
#endif
