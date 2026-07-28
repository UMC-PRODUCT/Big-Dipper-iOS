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

    // MARK: - Layout

    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? 0
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }

        return Self.wrapLayout(sizes: sizes, maxWidth: maxWidth, spacing: spacing).totalSize
    }

    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let wrap = Self.wrapLayout(sizes: sizes, maxWidth: bounds.width, spacing: spacing)
        let origins = wrap.origins

        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(x: bounds.minX + origins[index].x, y: bounds.minY + origins[index].y),
                proposal: .init(sizes[index])
            )
        }
    }

    // MARK: - Function

    /// 각 자식의 크기 배열을 순서대로 순회하며 wrap(줄바꿈) 배치 원점과 전체 크기를 계산합니다.
    ///
    /// `sizeThatFits`/`placeSubviews` 가 공유하는 순수 계산 로직이며, `Subviews`(SwiftUI 런타임 전용 타입)
    /// 없이도 `[CGSize]` 입력만으로 단위 테스트가 가능하도록 분리되어 있습니다.
    static func wrapLayout(
        sizes: [CGSize],
        maxWidth: CGFloat,
        spacing: CGFloat
    ) -> (origins: [CGPoint], totalSize: CGSize) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for size in sizes {
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            origins.append(CGPoint(x: x, y: y))

            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (origins, CGSize(width: maxWidth, height: y + rowHeight))
    }
}
