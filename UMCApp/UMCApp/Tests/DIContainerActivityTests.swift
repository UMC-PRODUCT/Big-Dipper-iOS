//
//  DIContainerActivityTests.swift
//  UMCAppTests
//
//  Created by jaewon Lee on 8/2/26.
//

import ActivityData
import ActivityDomain
import CoreDI
import CoreNetwork
import Foundation
import HomeData
import HomeDomain
import SwiftData
import Testing

@testable import UMCApp

// MARK: - Helpers

/// 프로토콜 하나의 해석을 이름과 함께 묶은 파라미터화 케이스.
///
/// `resolveIfRegistered` 는 정적 타입이 필요해 프로토콜 목록을 값으로 순회할 수 없다.
/// 각 해석을 클로저로 감싸 형제 케이스를 `arguments:` 하나로 통합한다.
private struct ActivityResolution: Sendable, CustomStringConvertible {
    let name: String
    let resolve: @Sendable (DIContainer) -> Any?

    var description: String { name }
}

/// Activity 의존성이 등록된 컨테이너를 만든다.
///
/// `DIContainer.configured(modelContext:)` 는 SwiftData 컨테이너를 요구하므로, Activity 조립이
/// 실제로 소비하는 공유 인프라(`MoyaNetworkAdapter`)만 운영과 같은 방식으로 먼저 등록한다.
/// 등록·해석 시점에는 네트워크 왕복이 없어 실제 어댑터를 그대로 쓴다.
///
/// Home 등록을 함께 태우는 이유: 출석·스터디 일정이 `HomeDomain` 의 canonical
/// `ScheduleRepositoryProtocol` 을 재사용하므로 Activity 단독 등록은 운영 부트스트랩
/// (`UMCAppApp`)과 다른 상태가 된다. 운영과 같은 순서로 조립해 실제 해석 경로를 검증한다.
///
/// Home 조립이 요구하는 `ModelContext` 는 디스크를 건드리지 않도록 인메모리 컨테이너에서 만든다.
/// `mainContext` 는 `@MainActor` 격리라 비격리 헬퍼에서 쓸 수 없어 새 컨텍스트를 직접 만든다.
private func makeContainer() throws -> DIContainer {
    let container = DIContainer()
    try registerNetworkAdapter(in: container)
    let modelContainer = try ModelContainer(
        for: GenerationMappingRecord.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.registerHomeDependencies(modelContext: ModelContext(modelContainer))
    container.registerActivityDependencies()
    return container
}

/// 테스트용 `MoyaNetworkAdapter` 를 등록한다.
///
/// - Parameter onFactoryCall: 팩토리가 실행될 때마다 호출된다. 공유 인프라가 몇 번 생성되는지
///   세는 회귀 테스트만 사용하고, 나머지 호출부는 기본값(no-op)을 쓴다.
private func registerNetworkAdapter(
    in container: DIContainer,
    onFactoryCall: @escaping () -> Void = {}
) throws {
    // 요청을 보내지 않는 테스트용 base URL.
    let baseURL = try #require(URL(string: "https://test.invalid"))
    container.register(MoyaNetworkAdapter.self) {
        onFactoryCall()
        return MoyaNetworkAdapter(
            networkClient: AuthSystemFactory.makeNetworkClient(baseURL: baseURL),
            baseURL: baseURL
        )
    }
}

// MARK: - Fixtures

private let providerResolutions: [ActivityResolution] = [
    ActivityResolution(name: "CurrentUserIdProviding") {
        $0.resolveIfRegistered(CurrentUserIdProviding.self)
    },
    ActivityResolution(name: "LocationProviding") {
        $0.resolveIfRegistered(LocationProviding.self)
    }
]

private let repositoryResolutions: [ActivityResolution] = [
    ActivityResolution(name: "ChallengerAttendanceRepositoryProtocol") {
        $0.resolveIfRegistered(ChallengerAttendanceRepositoryProtocol.self)
    },
    ActivityResolution(name: "OperatorAttendanceRepositoryProtocol") {
        $0.resolveIfRegistered(OperatorAttendanceRepositoryProtocol.self)
    },
    ActivityResolution(name: "StudyRepositoryProtocol") {
        $0.resolveIfRegistered(StudyRepositoryProtocol.self)
    },
    ActivityResolution(name: "MemberRepositoryProtocol") {
        $0.resolveIfRegistered(MemberRepositoryProtocol.self)
    }
]

private let useCaseResolutions: [ActivityResolution] = [
    ActivityResolution(name: "ChallengerAttendanceUseCaseProtocol") {
        $0.resolveIfRegistered(ChallengerAttendanceUseCaseProtocol.self)
    },
    ActivityResolution(name: "OperatorAttendanceUseCaseProtocol") {
        $0.resolveIfRegistered(OperatorAttendanceUseCaseProtocol.self)
    },
    ActivityResolution(name: "OperatorStudyManagementUseCaseProtocol") {
        $0.resolveIfRegistered(OperatorStudyManagementUseCaseProtocol.self)
    },
    ActivityResolution(name: "FetchCurriculumOverviewUseCaseProtocol") {
        $0.resolveIfRegistered(FetchCurriculumOverviewUseCaseProtocol.self)
    },
    ActivityResolution(name: "FetchMembersUseCaseProtocol") {
        $0.resolveIfRegistered(FetchMembersUseCaseProtocol.self)
    },
    ActivityResolution(name: "FetchStudyMembersUseCaseProtocol") {
        $0.resolveIfRegistered(FetchStudyMembersUseCaseProtocol.self)
    },
    ActivityResolution(name: "SearchChallengersUseCaseProtocol") {
        $0.resolveIfRegistered(SearchChallengersUseCaseProtocol.self)
    },
    ActivityResolution(name: "FetchUserIdUseCaseProtocol") {
        $0.resolveIfRegistered(FetchUserIdUseCaseProtocol.self)
    },
    ActivityResolution(name: "RegisterStudyScheduleUseCaseProtocol") {
        $0.resolveIfRegistered(RegisterStudyScheduleUseCaseProtocol.self)
    }
]

// MARK: - Tests

@Suite("DIContainer+Activity — Activity 의존성 조립 (도메인 규칙)")
struct DIContainerActivityTests {
    // MARK: - provider seam

    @Test("provider seam 이 등록되어 해석된다", arguments: providerResolutions)
    private func resolvesProviderSeam(_ resolution: ActivityResolution) throws {
        let container = try makeContainer()

        #expect(resolution.resolve(container) != nil)
    }

    /// 완료 조건 "`LocationManager` feature-local 재구현 없음" 의 회귀 가드.
    ///
    /// non-nil 검증만으로는 placeholder 나 feature 내부 재구현으로 바뀌어도 통과하므로,
    /// `ActivityData` 의 운영 어댑터 타입 자체를 고정한다.
    @Test("provider seam 은 ActivityData 의 운영 어댑터로 해석된다")
    func resolvesProductionProviderAdapters() throws {
        let container = try makeContainer()

        #expect(container.resolve(LocationProviding.self) is LocationManagerAdapter)
        #expect(
            container.resolve(CurrentUserIdProviding.self) is UserDefaultsCurrentUserIdProvider
        )
    }

    // MARK: - Repository

    @Test("Repository 프로토콜이 등록되어 해석된다", arguments: repositoryResolutions)
    private func resolvesRepository(_ resolution: ActivityResolution) throws {
        let container = try makeContainer()

        #expect(resolution.resolve(container) != nil)
    }

    // MARK: - UseCase

    @Test("UseCase 프로토콜이 등록되어 해석된다", arguments: useCaseResolutions)
    private func resolvesUseCase(_ resolution: ActivityResolution) throws {
        let container = try makeContainer()

        #expect(resolution.resolve(container) != nil)
    }

    // MARK: - 단일 구현체 공유

    @Test("챌린저·운영진 출석 Repository 는 같은 인스턴스로 해석된다")
    func attendanceRepositoryProtocolsShareInstance() throws {
        let container = try makeContainer()
        let challengerFacing = container.resolve(ChallengerAttendanceRepositoryProtocol.self)
        let operatorFacing = container.resolve(OperatorAttendanceRepositoryProtocol.self)

        let challenger = try #require(challengerFacing as? AttendanceRepository)
        let operatorSide = try #require(operatorFacing as? AttendanceRepository)

        #expect(challenger === operatorSide)
    }

    // MARK: - 공유 인프라 재사용

    @Test("Activity 등록은 MoyaNetworkAdapter 를 재등록하지 않고 기존 인스턴스를 재사용한다")
    func reusesRegisteredNetworkAdapter() throws {
        let container = DIContainer()
        var adapterFactoryCallCount = 0
        try registerNetworkAdapter(in: container) { adapterFactoryCallCount += 1 }
        container.registerActivityDependencies()

        _ = container.resolve(StudyRepositoryProtocol.self)
        _ = container.resolve(MemberRepositoryProtocol.self)
        _ = container.resolve(ChallengerAttendanceRepositoryProtocol.self)
        _ = container.resolve(OperatorAttendanceRepositoryProtocol.self)

        #expect(adapterFactoryCallCount == 1)
    }

    /// 완료 조건 "`ScheduleDetailData` 재사용 (중복 모델/조회 경로 신설 금지)" 의 회귀 가드.
    ///
    /// Activity 가 일정 Repository 를 자체 등록하면 미리 등록된 canonical 팩토리가 밀려나
    /// 호출 횟수가 0 이 된다. 1 이어야 Home 의 등록을 그대로 재사용했다는 뜻이다.
    @Test("일정 Repository 는 Home 이 등록한 canonical 을 재사용한다")
    func reusesCanonicalScheduleRepository() throws {
        let container = DIContainer()
        try registerNetworkAdapter(in: container)
        var scheduleRepositoryFactoryCallCount = 0
        container.register(ScheduleRepositoryProtocol.self) {
            scheduleRepositoryFactoryCallCount += 1
            return ScheduleRepository(adapter: container.resolve(MoyaNetworkAdapter.self))
        }
        container.registerActivityDependencies()

        _ = container.resolve(ChallengerAttendanceUseCaseProtocol.self)
        _ = container.resolve(RegisterStudyScheduleUseCaseProtocol.self)

        #expect(scheduleRepositoryFactoryCallCount == 1)
    }
}
