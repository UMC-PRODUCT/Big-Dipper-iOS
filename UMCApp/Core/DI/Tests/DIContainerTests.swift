//
//  DIContainerTests.swift
//  CoreDITests
//
//  Created by One on 5/14/26.
//

import Foundation
import Testing
@testable import CoreDI

// MARK: - Test Doubles

private protocol GreeterProtocol: AnyObject {
    var message: String { get }
}

private final class Greeter: GreeterProtocol {
    let message: String
    init(message: String = "hello") {
        self.message = message
    }
}

private protocol CounterProtocol: AnyObject {
    var value: Int { get }
}

private final class Counter: CounterProtocol {
    let value: Int
    init(value: Int = 0) {
        self.value = value
    }
}

// MARK: - Tests

@Suite("DIContainer")
struct DIContainerTests {

    @Test("register 후 resolve 시 팩토리가 생성한 인스턴스를 반환한다")
    func resolveReturnsRegisteredInstance() {
        let container = DIContainer()
        container.register(GreeterProtocol.self) { Greeter(message: "hi") }

        let resolved = container.resolve(GreeterProtocol.self)

        #expect(resolved.message == "hi")
    }

    @Test("resolve를 여러 번 호출해도 동일 인스턴스가 캐싱되어 반환된다")
    func resolveCachesInstance() {
        let container = DIContainer()
        container.register(GreeterProtocol.self) { Greeter() }

        let first = container.resolve(GreeterProtocol.self)
        let second = container.resolve(GreeterProtocol.self)

        #expect(first === second)
    }

    @Test("동일 타입을 다시 register하면 캐시는 유지되지만 새 resolve부터 새 팩토리가 적용된다")
    func reregisterReplacesFactoryButCacheWins() {
        let container = DIContainer()
        container.register(GreeterProtocol.self) { Greeter(message: "first") }
        _ = container.resolve(GreeterProtocol.self)

        container.register(GreeterProtocol.self) { Greeter(message: "second") }
        let afterReregister = container.resolve(GreeterProtocol.self)

        // 캐시가 우선이므로 기존 인스턴스가 반환된다
        #expect(afterReregister.message == "first")

        container.resetCache(for: GreeterProtocol.self)
        let afterReset = container.resolve(GreeterProtocol.self)

        #expect(afterReset.message == "second")
    }

    @Test("resolveIfRegistered는 미등록 타입에 대해 nil을 반환한다")
    func resolveIfRegisteredReturnsNilForUnregistered() {
        let container = DIContainer()

        let result = container.resolveIfRegistered(GreeterProtocol.self)

        #expect(result == nil)
    }

    @Test("resolveIfRegistered는 등록된 타입에 대해 인스턴스를 반환하고 캐싱한다")
    func resolveIfRegisteredCachesInstance() {
        let container = DIContainer()
        container.register(GreeterProtocol.self) { Greeter() }

        let first = container.resolveIfRegistered(GreeterProtocol.self)
        let second = container.resolveIfRegistered(GreeterProtocol.self)

        #expect(first != nil)
        #expect(first === second)
    }

    @Test("resolveIfCached는 이미 생성된 인스턴스를 그대로 반환한다")
    func resolveIfCachedReturnsLiveInstance() {
        let container = DIContainer()
        container.register(GreeterProtocol.self) { Greeter() }
        let resolved = container.resolve(GreeterProtocol.self)

        #expect(container.resolveIfCached(GreeterProtocol.self) === resolved)
    }

    /// 정리 코드(`resetCache()` 직전 `stop()`)가 쓰는 경로다. 미스 시 생성해 버리면 정리하려던
    /// 순간에 인스턴스가 하나 더 생겨 남는다 — `resolveIfRegistered`로 구현하면 이 테스트가 깨진다.
    @Test("resolveIfCached는 등록만 된 타입에 대해 nil을 반환하고 아무것도 생성·캐싱하지 않는다")
    func resolveIfCachedDoesNotCreateInstance() {
        let container = DIContainer()
        var factoryCallCount = 0
        container.register(GreeterProtocol.self) {
            factoryCallCount += 1
            return Greeter()
        }

        #expect(container.resolveIfCached(GreeterProtocol.self) == nil)
        #expect(factoryCallCount == 0)
        // 캐시가 오염되지 않았으므로 이후 resolve가 정상적으로 첫 인스턴스를 만든다.
        let resolved = container.resolve(GreeterProtocol.self)

        #expect(factoryCallCount == 1)
        #expect(container.resolveIfCached(GreeterProtocol.self) === resolved)
    }

    @Test("resetCache()는 모든 캐시된 인스턴스를 제거한다")
    func resetCacheClearsAllInstances() {
        let container = DIContainer()
        container.register(GreeterProtocol.self) { Greeter() }
        container.register(CounterProtocol.self) { Counter() }

        let greeterBefore = container.resolve(GreeterProtocol.self)
        let counterBefore = container.resolve(CounterProtocol.self)

        container.resetCache()

        let greeterAfter = container.resolve(GreeterProtocol.self)
        let counterAfter = container.resolve(CounterProtocol.self)

        #expect(greeterBefore !== greeterAfter)
        #expect(counterBefore !== counterAfter)
    }

    @Test("resetCache(for:)는 지정한 타입의 캐시만 제거하고 다른 타입은 유지한다")
    func resetCacheForTypeIsolatesScope() {
        let container = DIContainer()
        container.register(GreeterProtocol.self) { Greeter() }
        container.register(CounterProtocol.self) { Counter() }

        let greeterBefore = container.resolve(GreeterProtocol.self)
        let counterBefore = container.resolve(CounterProtocol.self)

        container.resetCache(for: GreeterProtocol.self)

        let greeterAfter = container.resolve(GreeterProtocol.self)
        let counterAfter = container.resolve(CounterProtocol.self)

        #expect(greeterBefore !== greeterAfter)
        #expect(counterBefore === counterAfter)
    }

    @Test("팩토리 클로저 내부에서 다른 의존성을 resolve하여 그래프를 구성할 수 있다")
    func factoryCanResolveOtherDependencies() {
        final class Composed {
            let greeter: GreeterProtocol
            let counter: CounterProtocol
            init(greeter: GreeterProtocol, counter: CounterProtocol) {
                self.greeter = greeter
                self.counter = counter
            }
        }

        let container = DIContainer()
        container.register(GreeterProtocol.self) { Greeter(message: "composed") }
        container.register(CounterProtocol.self) { Counter(value: 42) }
        container.register(Composed.self) {
            Composed(
                greeter: container.resolve(GreeterProtocol.self),
                counter: container.resolve(CounterProtocol.self)
            )
        }

        let composed = container.resolve(Composed.self)

        #expect(composed.greeter.message == "composed")
        #expect(composed.counter.value == 42)
    }
}
