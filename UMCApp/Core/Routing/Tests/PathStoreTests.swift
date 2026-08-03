//
//  PathStoreTests.swift
//  CoreRoutingTests
//
//  Created by 이재원 on 7/30/26.
//

import SwiftUI
import Testing

import CoreRouting

// MARK: - Helper

private func makeStore() -> PathStore {
    PathStore()
}

/// 경로 원소로 쓰는 테스트용 목적지.
///
/// `PathStore`는 원소의 의미를 해석하지 않고 `Hashable`이기만 하면 담는다. 실제 Feature
/// 목적지 대신 스텁을 쓰는 이유가 그것으로, 스텁의 필드 값 자체는 검증과 무관하다.
private struct StubDestination: Hashable {
    let id: String
}

/// `StubDestination`과 **다른 타입**임을 드러내기 위한 두 번째 스텁.
///
/// 타입 소거 경로가 이종 타입을 함께 담는지 확인할 때만 쓴다.
private struct OtherStubDestination: Hashable {
    let index: Int
}

// MARK: - 경로 전이

@Suite("PathStore — 경로 push/pop 전이 (도메인 규칙)")
struct PathStoreTransitionTests {

    @Test("초기 상태의 탭은 루트다")
    func startsAtRoot() {
        let store = makeStore()

        #expect(store.isAtRoot(.activity))
    }

    @Test("push하면 스택 깊이가 1 늘어난다")
    func pushIncreasesDepth() {
        let store = makeStore()

        store.push(StubDestination(id: "detail"), on: .activity)

        #expect(store.depth(of: .activity) == 1)
    }

    /// `NavigationStack` 이 뒤로가기로 경로를 되돌려도 그 탭만 줄어든다.
    /// 스택 바인딩이 실제로 쓰는 통로가 subscript 이므로 그 경로로 검증한다.
    @Test("경로를 되돌리면 직전 깊이로 돌아간다")
    func rewindingRestoresPreviousDepth() {
        let store = makeStore()
        store.push(StubDestination(id: "first"), on: .activity)
        store.push(StubDestination(id: "second"), on: .activity)

        store[.activity].removeLast()

        #expect(store.depth(of: .activity) == 1)
    }

    /// 이 모듈이 `NavigationPath`(타입 소거)를 쓰는 이유 자체를 고정하는 테스트.
    /// Feature마다 자기 목적지 타입을 소유해도 한 탭 스택에 함께 쌓여야 한다.
    @Test("서로 다른 목적지 타입을 한 스택에 함께 쌓는다")
    func mixesHeterogeneousDestinationTypes() {
        let store = makeStore()

        store.push(StubDestination(id: "detail"), on: .activity)
        store.push(OtherStubDestination(index: 1), on: .activity)

        #expect(store.depth(of: .activity) == 2)
    }
}

// MARK: - 탭 격리

@Suite("PathStore — 탭별 스택 격리 (도메인 규칙)")
struct PathStoreTabIsolationTests {

    @Test("한 탭에 push해도 나머지 탭은 루트를 유지한다", arguments: NavigationTab.allCases)
    func pushDoesNotLeakToOtherTabs(pushedTab: NavigationTab) {
        let store = makeStore()

        store.push(StubDestination(id: "detail"), on: pushedTab)

        #expect(store.depth(of: pushedTab) == 1)
        let leaked = NavigationTab.allCases
            .filter { $0 != pushedTab }
            .filter { !store.isAtRoot($0) }
        #expect(leaked.isEmpty)
    }

    @Test("한 탭의 경로를 비워도 다른 탭은 그대로다", arguments: NavigationTab.allCases)
    func clearingOneTabKeepsOthers(clearedTab: NavigationTab) {
        let store = makeStore()
        for tab in NavigationTab.allCases {
            store.push(StubDestination(id: "detail"), on: tab)
        }

        store[clearedTab] = NavigationPath()

        #expect(store.isAtRoot(clearedTab))
        let unexpectedlyCleared = NavigationTab.allCases
            .filter { $0 != clearedTab }
            .filter { store.depth(of: $0) != 1 }
        #expect(unexpectedlyCleared.isEmpty)
    }
}
