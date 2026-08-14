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
    static let shimmerDuration: Double = 1.1
    static let loadingLabel = "대화를 불러오는 중"
    /// 이름·시각 자리의 폭. 뼈대가 맞춰야 하는 건 폭이 아니라 높이라(가로는 어긋나도 버블이
    /// 제자리에 있으면 도약이 없다) 닉네임·시각 표기의 대표 길이로 고정해 둔다.
    static let senderWidth: CGFloat = 56
    static let timeWidth: CGFloat = 40
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
///
/// 그래서 줄을 이루는 요소를 `MessageBubble` 과 하나씩 맞춰 둔다. 기본 크기 기준으로 수신은
/// 이름 13 + 4 + 버블 36(본문 한 줄 20 + 세로 패딩 8×2) + 4 + 시각 13 + 줄 세로 패딩 4×2 =
/// 78pt, 발신은 이름이 빠져 36 + 4 + 13 + 8 = 61pt 이고, 여기 깔린 다섯 줄(수신 3 + 발신 2)은
/// 78×3 + 61×2 = 356pt 로 같은 구성의 실제 메시지 다섯 개와 같아진다.
///
/// 이 숫자를 상수로 박지 않고 실제와 같은 서체·패딩을 태운 숨긴 `Text` 에서 얻는다. 한 줄의
/// 실제 픽셀 높이는 Pretendard 의 라인 높이와 Dynamic Type 배율에 따라 위 값에서 1pt 안팎으로
/// 움직이는데, 상수로 두면 그 차이가 그대로 어긋남이 되고 접근성 크기에서는 실제 목록만 커져
/// 벌어진다. 같은 서체를 태워 두면 어느 크기에서든 두 값이 함께 움직인다.
///
/// `DateDivider` 자리는 그리지 않는다. 구분선이 몇 개 어디에 들어가는지는 받아 온 메시지의
/// 날짜에 달려 있어 뼈대가 맞출 수 없고, 아래에 붙여 그리므로 어긋난 만큼은 화면 위쪽에서만
/// 밀린다 — 눈이 머무는 최하단은 그대로다.
struct MessageListSkeleton: View {

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Constants.rows, id: \.self) { row in
                SkeletonBubble(row: row)
            }
        }
        .padding(.horizontal, DefaultSpacing.spacing16)
        // 실제 목록은 `.defaultScrollAnchor(.bottom)` 으로 아래에 착지한다. 뼈대를 위에 붙여
        // 두면 교체 순간 말풍선 덩어리가 통째로 내려간다. 하단 여백도 주지 않는다 — 실제
        // 목록의 마지막 버블 아래에도 그 버블의 세로 패딩 4pt 말고는 아무것도 없다.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        // 뼈대 줄 하나하나를 읽어 줄 이유가 없다. 지금 무엇을 기다리는지만 알리면 된다.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Constants.loadingLabel)
    }
}

// MARK: - Skeleton Bubble

/// 뼈대 말풍선 한 개. 바깥 구조(이름·버블·시각·세로 패딩)를 `MessageBubble` 그대로 따른다.
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
        HStack(alignment: .bottom, spacing: DefaultSpacing.spacing8) {
            if row.isMine {
                Spacer(minLength: DefaultSpacing.spacing32)
            }

            VStack(alignment: alignment, spacing: DefaultSpacing.spacing4) {
                VStack(alignment: alignment, spacing: DefaultSpacing.spacing4) {
                    // 발신 버블에는 실제 목록에도 이름이 없다.
                    if !row.isMine {
                        captionPlaceholder(width: Constants.senderWidth)
                    }
                    bubble
                }

                captionPlaceholder(width: Constants.timeWidth)
            }

            if !row.isMine {
                Spacer(minLength: DefaultSpacing.spacing32)
            }
        }
        .padding(.vertical, DefaultSpacing.spacing4)
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

    // MARK: - View Component

    /// 실제 버블과 같은 서체·세로 패딩을 태운 한 줄이라 높이가 저절로 따라온다.
    /// 빈 문자열은 높이가 접힐 수 있어 공백 한 칸을 쓴다.
    private var bubble: some View {
        Text(" ")
            .appFont(.subheadline)
            .hidden()
            .padding(.vertical, DefaultSpacing.spacing8)
            .frame(width: row.width)
            .background(shimmer, in: .rect(cornerRadius: Constants.cornerRadius))
    }

    /// 이름·시각 자리. 같은 방식으로 `caption2` 한 줄 높이를 그대로 가져온다.
    /// 빛은 버블에만 흘린다 — 한 줄에서 세 덩어리가 같이 깜빡이면 대기 표시가 산만해진다.
    private func captionPlaceholder(width: CGFloat) -> some View {
        Text(" ")
            .appFont(.caption2)
            .hidden()
            .frame(width: width)
            .background(Color.grey100, in: .capsule)
    }

    // MARK: - Computed Property

    private var alignment: HorizontalAlignment {
        row.isMine ? .trailing : .leading
    }

    private var shimmer: LinearGradient {
        LinearGradient(
            colors: [.grey100, .grey200, .grey100],
            startPoint: isAnimating ? .init(x: 1, y: 0.5) : .init(x: -1, y: 0.5),
            endPoint: isAnimating ? .init(x: 2, y: 0.5) : .init(x: 0, y: 0.5)
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    // 실제 화면처럼 남는 공간을 위에 두고 뼈대가 아래에 붙는지 본다.
    VStack(spacing: 0) {
        MessageListSkeleton()

        Divider()
    }
    .frame(maxHeight: .infinity, alignment: .bottom)
}
#endif
