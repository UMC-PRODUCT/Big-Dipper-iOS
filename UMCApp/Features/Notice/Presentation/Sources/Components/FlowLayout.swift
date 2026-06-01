//
//  FlowLayout.swift
//  NoticePresentation
//
//  Created by 이예지 on 6/1/26.
//

import SwiftUI

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

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
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

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
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

            subview.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: .init(size))

            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}
