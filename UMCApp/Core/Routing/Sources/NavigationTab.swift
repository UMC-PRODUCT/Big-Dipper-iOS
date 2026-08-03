//
//  NavigationTab.swift
//  CoreRouting
//
//  Created by 이재원 on 7/30/26.
//

/// 루트 탭 셸이 가지는 탭의 **라우팅 정체성**.
///
/// 탭마다 독립된 네비게이션 스택을 갖기 때문에, 경로를 저장·조회하려면 "어느 탭인가"를
/// 가리키는 키가 필요하다. 그 키가 이 타입이다.
///
/// 제목·SF Symbol·`TabRole` 같은 표시 정보는 App 셸의 관심사이므로 여기에 두지 않고
/// App 타깃의 확장에서 붙인다. 그래야 Feature 모듈이 라우팅만 필요할 때
/// SwiftUI 표현 계층을 함께 끌고 오지 않는다.
public enum NavigationTab: CaseIterable, Identifiable, Hashable, Sendable {
    case home
    case notice
    case activity
    case community
    case mypage

    public var id: Self { self }
}
