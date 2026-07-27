//
//  CapsuleModifier.swift
//  CoreUIComponents
//
//  Created by euijjang97 on 1/18/26.
//

import SwiftUI
import CoreDesignSystem

fileprivate enum Constants {
    static let width: CGFloat = 40
    static let height: CGFloat = 5
}

/// 캡슐 형태의 그랩 핸들(bottom sheet drag indicator)에 사용하는 ViewModifier
public struct CapsuleModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .frame(width: Constants.width, height: Constants.height)
            .foregroundStyle(Color.grey400)
    }
}

extension View {
    /// 캡슐 형태의 그랩 핸들 스타일을 적용합니다.
    public func capsuleHandle() -> some View {
        modifier(CapsuleModifier())
    }
}
