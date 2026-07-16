//
//  NavigationModifier.swift
//  CoreUIComponents
//
//  Created by 이예지 on 6/1/26.
//

import Foundation
import SwiftUI

/// 네비게이션 바의 타이틀과 표시 모드를 설정하는 커스텀 ViewModifier입니다.
///
/// `NavigationTitle` 네임스페이스의 피처별 타이틀을 통해 중앙 관리합니다.
public struct NavigationModifier: ViewModifier {
    public let title: String
    public let displayMode: NavigationBarItem.TitleDisplayMode

    public init(naviTitle: some NavigationTitleRepresentable,
                displayMode: NavigationBarItem.TitleDisplayMode) {
        self.title = naviTitle.rawValue
        self.displayMode = displayMode
    }

    public func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(displayMode)
    }
}

extension View {
    /// 네비게이션 타이틀과 디스플레이 모드를 간편하게 설정하는 메서드입니다.
    ///
    /// - Parameters:
    ///   - naviTitle: `NavigationTitle` 네임스페이스의 피처별 타이틀 값
    ///   - displayMode: 타이틀 표시 모드 (.inline, .large 등)
    /// - Returns: NavigationModifier가 적용된 View
    public func navigation(naviTitle: some NavigationTitleRepresentable,
                           displayMode: NavigationBarItem.TitleDisplayMode) -> some View {
        modifier(NavigationModifier(naviTitle: naviTitle, displayMode: displayMode))
    }
}

