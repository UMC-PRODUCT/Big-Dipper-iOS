//
//  PathStore.swift
//  CoreRouting
//
//  Created by 이재원 on 7/30/26.
//

import SwiftUI

/// 탭별 네비게이션 경로를 한 곳에서 관리하는 전역 Store.
///
/// 절대규칙 #1의 명시적 예외(앱 생명주기 전역 관리자)로 `@Observable`을 사용한다.
/// App 셸이 소유해 `.environment`로 주입하고, 각 탭의 `NavigationStack`이 path 바인딩
/// 소스로 쓴다.
///
/// ## 왜 `NavigationPath`(타입 소거)인가
///
/// 경로를 `[SomeDestination]`처럼 한 가지 타입의 배열로 두면, 모든 Feature의 목적지를
/// 하나의 enum에 모아야 하고 그 enum이 있는 모듈은 모든 Feature의 도메인 타입에 의존하게
/// 된다. 즉 Core → Feature 역방향 의존이 생긴다.
///
/// `NavigationPath`는 서로 다른 `Hashable` 타입을 한 스택에 섞어 담을 수 있으므로,
/// **각 Feature가 자기 목적지 타입을 자기 모듈에서 소유**하고 그 Feature의 루트 화면이
/// `.navigationDestination(for:)`을 자기 탭 스택에 등록하는 구성이 가능해진다. 등록까지
/// Feature가 맡으므로 목적지 화면을 `public`으로 열 필요도 없다. 그 결과
/// Core → Feature 의존과 Feature → App 의존을 동시에 피한다.
///
/// - Note: `NavigationPath`는 담긴 원소를 되읽을 수 없다(`count`/`isEmpty`만 공개).
///   따라서 "무엇이 쌓였는지"가 아니라 "얼마나 쌓였는지"와 탭 간 격리가 이 타입의 계약이다.
/// - Note: 액터 격리를 두지 않은 것은 형제 전역 관리자(`ErrorHandler`·`UserSessionManager`)와
///   같은 선택이다. 실제 접근은 모두 SwiftUI 뷰(메인 액터)에서 일어난다. 공유 관찰 객체의
///   격리 정책을 바꾼다면 세 타입을 함께 다뤄야 하므로 여기서 단독으로 갈라지지 않는다.
@Observable
public final class PathStore {

    // MARK: - Property

    /// 탭별 경로. 값이 없는 탭은 루트(빈 경로)로 취급한다.
    private var paths: [NavigationTab: NavigationPath] = [:]

    // MARK: - Init

    public init() {}

    // MARK: - Subscript

    /// 탭의 경로에 접근한다. `NavigationStack(path:)` 바인딩의 소스로 쓴다.
    public subscript(tab: NavigationTab) -> NavigationPath {
        get { paths[tab] ?? NavigationPath() }
        set { paths[tab] = newValue }
    }

    // MARK: - Function

    /// 탭 스택에 목적지를 push한다.
    ///
    /// 어떤 `Hashable` 타입이든 받으므로 Feature는 자기 목적지 타입만 알면 된다.
    public func push(_ destination: some Hashable, on tab: NavigationTab) {
        self[tab].append(destination)
    }

    /// 탭 스택에 쌓인 화면 수(루트 제외).
    public func depth(of tab: NavigationTab) -> Int {
        self[tab].count
    }

    /// 탭이 루트에 있는지 여부.
    public func isAtRoot(_ tab: NavigationTab) -> Bool {
        self[tab].isEmpty
    }
}
