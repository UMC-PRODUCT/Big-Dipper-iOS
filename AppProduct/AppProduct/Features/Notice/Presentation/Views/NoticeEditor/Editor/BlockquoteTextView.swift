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

    /// `refreshBlockquoteBorders` 호출이 필요한 상태임을 나타냅니다.
    private var needsBlockquoteRefresh = false

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
        if needsBlockquoteRefresh {
            needsBlockquoteRefresh = false
            refreshBlockquoteBorders()
        }
    }

    // MARK: - Blockquote Rendering

    /// 다음 레이아웃 패스에서 인용구 경계선을 갱신하도록 예약합니다.
    func setNeedsBlockquoteRefresh() {
        needsBlockquoteRefresh = true
        setNeedsLayout()
    }

    /// 텍스트 스토리지에서 인용구 속성을 읽어 왼쪽 경계선 레이어를 즉시 업데이트합니다.
    func refreshBlockquoteBorders() {
        needsBlockquoteRefresh = false
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
        // 레이아웃이 확정되지 않은 상태에서 line fragment를 열거하면
        // 경계선 높이가 한 프레임 짧게 계산될 수 있습니다.
        lm.ensureLayout(for: textContainer)
        let tcInset = textContainerInset
        let fragPadding = textContainer.lineFragmentPadding
        let nsString = storage.string as NSString

        // 단락 단위로 순회하여 하나의 단락에 레이어 하나만 생성 (attribute run 분리 무시)
        var location = 0
        while location < storage.length {
            let paragraphRange = nsString.paragraphRange(for: NSRange(location: location, length: 0))
            let checkLocation = min(paragraphRange.location, storage.length - 1)

            guard (storage.attribute(.editorBlockquote, at: checkLocation, effectiveRange: nil) as? Bool) == true else {
                let next = NSMaxRange(paragraphRange)
                guard next > location else { break }
                location = next
                continue
            }

            let borderColor = storage.attribute(
                .editorBlockquoteBorderColor,
                at: checkLocation,
                effectiveRange: nil
            ) as? UIColor ?? .systemGray3

            let baseIndent = (storage.attribute(
                .editorBlockquoteBaseHeadIndent,
                at: checkLocation,
                effectiveRange: nil
            ) as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0

            let glyphRange = lm.glyphRange(forCharacterRange: paragraphRange, actualCharacterRange: nil)

            var minY: CGFloat = .greatestFiniteMagnitude
            var maxY: CGFloat = -.greatestFiniteMagnitude

            lm.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, _, _ in
                minY = min(minY, usedRect.minY + tcInset.top)
                maxY = max(maxY, usedRect.maxY + tcInset.top)
            }

            if minY < maxY {
                let xPos = tcInset.left + fragPadding + baseIndent
                let borderRect = CGRect(x: xPos, y: minY, width: borderWidth, height: maxY - minY)
                let path = UIBezierPath(roundedRect: borderRect, cornerRadius: cornerRadius)

                let borderLayer = CAShapeLayer()
                borderLayer.path = path.cgPath
                borderLayer.fillColor = borderColor.cgColor

                // zPosition=-1 대신 레이어 최하단에 삽입하여 합성 문제를 방지합니다.
                layer.insertSublayer(borderLayer, at: 0)
                blockquoteLayers.append(borderLayer)
            }

            let next = NSMaxRange(paragraphRange)
            guard next > location else { break }
            location = next
        }
    }
}
