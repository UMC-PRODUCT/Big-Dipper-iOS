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

/// 대형 타이틀을 **툴바 행 안에** 그리는 ViewModifier입니다.
///
/// `.large`(``NavigationModifier``)는 타이틀을 바 아래 별도 행으로 내리기 때문에 trailing
/// 툴바 버튼과 위아래로 갈립니다. `.inlineLarge`는 큰 타이틀을 툴바 안에 그려 버튼과 한 행에
/// 놓습니다 — 시안이 그 배치를 요구할 때 씁니다.
///
/// - Important: `.inlineLarge`는 leading·centered 툴바 아이템을 오버플로 메뉴로 밀어냅니다
///   (Apple 문서). trailing 아이템만 두는 화면에서 쓰세요.
public struct InlineLargeTitleModifier: ViewModifier {
    public let title: String

    public init(naviTitle: some NavigationTitleRepresentable) {
        self.title = naviTitle.rawValue
    }

    public func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .toolbarTitleDisplayMode(.inlineLarge)
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

    /// 큰 타이틀을 툴바 행 안에 그립니다 (``InlineLargeTitleModifier`` 참고).
    ///
    /// - Parameter naviTitle: `NavigationTitle` 네임스페이스의 피처별 타이틀 값
    public func navigationInlineLarge(
        naviTitle: some NavigationTitleRepresentable
    ) -> some View {
        modifier(InlineLargeTitleModifier(naviTitle: naviTitle))
    }
}

