//
//  SymbolDrawOnModifier.swift
//  AppProduct
//
//  Created by euijjang97 on 6/3/26.
//

import SwiftUI

// MARK: - View+SymbolDrawOn

extension View {

    /// 긍정적 상태 전환(승인·완료·읽음 확인·선택 등) 시 SF Symbol을 펜으로 긋듯
    /// 선을 따라 그리는 `drawOn` 등장 애니메이션을 적용합니다.
    ///
    /// `isActive`가 `true`가 되는 순간 심볼이 그려지며 나타나고,
    /// 비활성일 때는 효과 없이 심볼이 그대로 표시됩니다.
    ///
    /// - Important: `circle ↔ checkmark.circle.fill`처럼 두 심볼을 오가는 체크박스 토글에는
    ///   적합하지 않습니다(빈 상태 심볼까지 다시 그려져 어색함).
    ///   그런 경우는 `contentTransition(.symbolEffect(.replace))`를 사용하세요.
    /// - Note: 손쉬운 사용의 "동작 줄이기"(Reduce Motion)가 켜져 있으면 모션을 생략하고
    ///   심볼을 즉시 표시합니다. 비활성(`isActive == false`)일 때도 효과를 부착하지 않아
    ///   어떤 상황에서도 심볼이 숨겨지지 않습니다.
    ///
    /// - Parameter isActive: 심볼을 그려서 등장시킬지 여부.
    func symbolDrawOn(isActive: Bool) -> some View {
        modifier(SymbolDrawOnModifier(isActive: isActive))
    }
}

// MARK: - SymbolDrawOnModifier

/// `symbolEffect(.drawOn:)`을 Reduce Motion 설정과 함께 적용하는 ViewModifier입니다.
private struct SymbolDrawOnModifier: ViewModifier {

    // MARK: - Property

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 등장 직후 `false → true` 전환을 주기 위한 내부 상태.
    ///
    /// `.drawOn`은 `isActive`가 `false → true`로 **전환되는 순간**에만 그리기 애니메이션을
    /// 재생합니다. 심볼이 이미 `isActive == true`인 상태로 새로 삽입되면 전환 트리거가
    /// 없어 "그려지지 않은(=비표시)" 상태로 남으므로, 등장 시점에 직접 토글합니다.
    @State private var hasDrawn = false

    let isActive: Bool

    // MARK: - Body

    func body(content: Content) -> some View {
        if isActive && !reduceMotion {
            content
                .symbolEffect(.drawOn, isActive: hasDrawn)
                .onAppear { hasDrawn = true }
        } else {
            content
        }
    }
}
