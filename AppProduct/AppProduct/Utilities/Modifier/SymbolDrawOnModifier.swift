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
    /// 심볼이 뷰 계층에 **삽입되는 순간** 그려지며 나타나고, 삽입 애니메이션이 없을 때는
    /// 효과 없이 그려진 최종 상태로 그대로 표시됩니다.
    ///
    /// - Important: `circle ↔ checkmark.circle.fill`처럼 두 심볼을 오가는 체크박스 토글에는
    ///   적합하지 않습니다(빈 상태 심볼까지 다시 그려져 어색함).
    ///   그런 경우는 `contentTransition(.symbolEffect(.replace))`를 사용하세요.
    /// - Important: `.drawOn`은 **전환(transition) 효과**이므로 `.symbolEffect(.drawOn, isActive:)`
    ///   같은 지속(indefinite) 오버로드로 쓰면, 심볼이 이미 최종 상태로 새로 삽입될 때
    ///   "그려지지 않은(=투명)" 상태로 남습니다. 따라서 전환 API(`.transition(.symbolEffect(.drawOn))`)로
    ///   적용합니다 — 삽입 애니메이션이 있으면 그려지며 등장하고, 없으면 그냥 보입니다.
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

/// `.transition(.symbolEffect(.drawOn))`을 Reduce Motion 설정과 함께 적용하는 ViewModifier입니다.
private struct SymbolDrawOnModifier: ViewModifier {

    // MARK: - Property

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isActive: Bool

    // MARK: - Body

    func body(content: Content) -> some View {
        if isActive && !reduceMotion {
            content
                .transition(.symbolEffect(.drawOn))
        } else {
            content
        }
    }
}
