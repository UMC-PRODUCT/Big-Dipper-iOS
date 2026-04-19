//
//  BlockquoteTextView.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import UIKit

final class BlockquoteTextView: UITextView {

    // MARK: - Property

    private var blockquoteLayers: [CAShapeLayer] = []
    private var needsBlockquoteRefresh = false

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        if needsBlockquoteRefresh {
            needsBlockquoteRefresh = false
            refreshBlockquoteBorders()
        }
    }

    // MARK: - Blockquote Rendering

    func setNeedsBlockquoteRefresh() {
        needsBlockquoteRefresh = true
        setNeedsLayout()
    }

    func refreshBlockquoteBorders() {
        needsBlockquoteRefresh = false
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let storage = textStorage
        blockquoteLayers.forEach { $0.removeFromSuperlayer() }
        blockquoteLayers.removeAll()

        guard storage.length > 0 else { return }

        let borderWidth: CGFloat = 3
        let cornerRadius: CGFloat = 1.5
        let lm = layoutManager
        // 레이아웃이 확정되지 않은 상태에서 line fragment를 열거하면
        // 경계선 높이가 한 프레임 짧게 계산될 수 있습니다.
        lm.ensureLayout(for: textContainer)
        let tcInset = textContainerInset
        let fragPadding = textContainer.lineFragmentPadding
        let nsString = storage.string as NSString

        var location = 0
        var groupMinY: CGFloat = .greatestFiniteMagnitude
        var groupMaxY: CGFloat = -.greatestFiniteMagnitude
        var groupBorderColor: UIColor = .systemGray3
        var groupBaseIndent: CGFloat = 0
        var hasActiveGroup = false

        func flushGroup() {
            addBorderLayer(
                minY: groupMinY, maxY: groupMaxY,
                xPos: tcInset.left + fragPadding + groupBaseIndent,
                borderWidth: borderWidth, cornerRadius: cornerRadius,
                borderColor: groupBorderColor
            )
            hasActiveGroup = false
        }

        while location < storage.length {
            let paragraphRange = nsString.paragraphRange(for: NSRange(location: location, length: 0))
            let checkLocation = min(paragraphRange.location, storage.length - 1)
            let isBlockquote = (storage.attribute(.editorBlockquote, at: checkLocation, effectiveRange: nil) as? Bool) == true

            if isBlockquote {
                let currentBorderColor = storage.attribute(.editorBlockquoteBorderColor, at: checkLocation, effectiveRange: nil) as? UIColor ?? .systemGray3
                let currentBaseIndent = (storage.attribute(.editorBlockquoteBaseHeadIndent, at: checkLocation, effectiveRange: nil) as? NSNumber)
                    .map { CGFloat($0.doubleValue) } ?? 0

                // 시각 속성이 변경되면 이전 그룹을 flush하고 새 그룹 시작
                if hasActiveGroup && (currentBorderColor != groupBorderColor || abs(currentBaseIndent - groupBaseIndent) > 0.5) {
                    flushGroup()
                }

                if !hasActiveGroup {
                    groupBorderColor = currentBorderColor
                    groupBaseIndent = currentBaseIndent
                    groupMinY = .greatestFiniteMagnitude
                    groupMaxY = -.greatestFiniteMagnitude
                    hasActiveGroup = true
                }

                let glyphRange = lm.glyphRange(forCharacterRange: paragraphRange, actualCharacterRange: nil)
                lm.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, _, _ in
                    groupMinY = min(groupMinY, usedRect.minY + tcInset.top)
                    groupMaxY = max(groupMaxY, usedRect.maxY + tcInset.top)
                }

                // 빈 단락(glyph 없음)에서 line fragment가 생성되지 않는 경우
                // 커서 위치 기반으로 높이를 보정합니다.
                if glyphRange.length == 0 {
                    let cursorRect = lm.extraLineFragmentRect
                    if cursorRect.height > 0 {
                        groupMinY = min(groupMinY, cursorRect.minY + tcInset.top)
                        groupMaxY = max(groupMaxY, cursorRect.maxY + tcInset.top)
                    }
                }
            } else if hasActiveGroup {
                flushGroup()
            }

            let next = NSMaxRange(paragraphRange)
            guard next > location else { break }
            location = next
        }

        if hasActiveGroup {
            // EOF 빈 단락(커서만 있는 상태): extraLineFragmentRect로 높이 보정
            // 마지막 저장 문자와 커서의 typingAttributes 모두 인용구여야 확장합니다.
            // 인용구 탈출 직후에는 typingAttributes에서 인용구가 제거되므로
            // 이전 단락의 trailing \n 속성만으로 경계선이 연장되지 않습니다.
            let extraRect = lm.extraLineFragmentRect
            let lastCharIsBlockquote = (storage.attribute(.editorBlockquote, at: storage.length - 1, effectiveRange: nil) as? Bool) == true
            let cursorIsInBlockquote = (typingAttributes[.editorBlockquote] as? Bool) == true
            if extraRect.height > 0, lastCharIsBlockquote, cursorIsInBlockquote {
                groupMinY = min(groupMinY, extraRect.minY + tcInset.top)
                groupMaxY = max(groupMaxY, extraRect.maxY + tcInset.top)
            }
            flushGroup()
        }
    }

    // MARK: - Private

    private func addBorderLayer(
        minY: CGFloat, maxY: CGFloat,
        xPos: CGFloat,
        borderWidth: CGFloat, cornerRadius: CGFloat,
        borderColor: UIColor
    ) {
        guard minY < maxY else { return }
        let borderRect = CGRect(x: xPos, y: minY, width: borderWidth, height: maxY - minY)
        let borderLayer = CAShapeLayer()
        borderLayer.path = UIBezierPath(roundedRect: borderRect, cornerRadius: cornerRadius).cgPath
        borderLayer.fillColor = borderColor.cgColor
        layer.insertSublayer(borderLayer, at: 0)
        blockquoteLayers.append(borderLayer)
    }
}
