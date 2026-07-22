//
//  FlowLayout.swift
//  CoreUIComponents
//
//  Created by jaewon Lee on 7/15/26.
//

import SwiftUI

/// 자식 뷰를 가로로 배치하다가 폭을 넘으면 다음 줄로 넘기는 flow(wrap) 레이아웃입니다.
///
/// 태그·칩처럼 개수가 가변인 요소를 자연스럽게 줄바꿈 배치할 때 사용합니다.
///
/// - Note: 같은 `FlowLayout` 이 NoticePresentation 에도 로컬로 하나 더 있습니다.
///   여러 피처가 함께 쓰는 순수 레이아웃이라, 앞으로 이 canonical 하나로 합치는 게 목표입니다.
///   // TODO: NoticePresentation 로컬 FlowLayout 을 이 canonical 로 통합 - [26.07.15] 이재원
public struct FlowLayout: Layout {
    public var alignment: Alignment
    public var spacing: CGFloat

    // MARK: - Init

    public init(
        alignment: Alignment = .leading,
        spacing: CGFloat = 10
    ) {
        self.alignment = alignment
        self.spacing = spacing
    }

    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        height = y + rowHeight

        return CGSize(width: maxWidth, height: height)
    }

    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let maxWidth = bounds.width
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                proposal: .init(size)
            )

            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}
