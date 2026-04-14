//
//  BlockquoteTextView.swift
//  AppProduct
//
//  Created by euijjang97 on 4/8/26.
//

import UIKit

/// 인용구 속성이 적용된 단락에 왼쪽 세로 경계선을 렌더링하는 UITextView 서브클래스입니다.
final class BlockquoteTextView: UITextView {

    // MARK: - Property

    /// 인용구 영역별 개별 경계선 레이어를 관리합니다.
    private var blockquoteLayers: [CAShapeLayer] = []

    // MARK: - Initializer

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        refreshBlockquoteBorders()
    }

    // MARK: - Blockquote Rendering

    /// 텍스트 스토리지에서 인용구 속성을 읽어 왼쪽 경계선 레이어를 업데이트합니다.
    func refreshBlockquoteBorders() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let storage = textStorage

        // 기존 레이어 모두 제거
        for borderLayer in blockquoteLayers {
            borderLayer.removeFromSuperlayer()
        }
        blockquoteLayers.removeAll()

        guard storage.length > 0 else { return }

        let borderWidth: CGFloat = 3
        let cornerRadius: CGFloat = 1.5
        let lm = layoutManager
        let tcInset = textContainerInset
        let fragPadding = textContainer.lineFragmentPadding

        storage.enumerateAttribute(
            .editorBlockquote,
            in: NSRange(location: 0, length: storage.length),
            options: []
        ) { value, charRange, _ in
            guard value != nil else { return }

            let borderColor = storage.attribute(
                .editorBlockquoteBorderColor,
                at: charRange.location,
                effectiveRange: nil
            ) as? UIColor ?? .systemGray3

            let baseIndent = (storage.attribute(
                .editorBlockquoteBaseHeadIndent,
                at: charRange.location,
                effectiveRange: nil
            ) as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0

            let glyphRange = lm.glyphRange(forCharacterRange: charRange, actualCharacterRange: nil)

            var minY: CGFloat = .greatestFiniteMagnitude
            var maxY: CGFloat = -.greatestFiniteMagnitude

            lm.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, _, _ in
                minY = min(minY, usedRect.minY + tcInset.top)
                maxY = max(maxY, usedRect.maxY + tcInset.top)
            }

            guard minY < maxY else { return }

            // 경계선 x: 기본 들여쓰기 위치에 배치 (blockquote 이전 들여쓰기 기준)
            let xPos = tcInset.left + fragPadding + baseIndent
            let borderRect = CGRect(x: xPos, y: minY, width: borderWidth, height: maxY - minY)
            let path = UIBezierPath(roundedRect: borderRect, cornerRadius: cornerRadius)

            let borderLayer = CAShapeLayer()
            borderLayer.zPosition = -1
            borderLayer.path = path.cgPath
            borderLayer.fillColor = borderColor.cgColor

            layer.addSublayer(borderLayer)
            blockquoteLayers.append(borderLayer)
        }
    }
}
