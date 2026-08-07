//
//  DIContainer+Activity.swift
//  UMCApp
//
//  Created by jaewon Lee on 8/2/26.
//

import ActivityData
import ActivityDomain
import CoreDI
import CoreNetwork
import HomeDomain

extension DIContainer {
    /// Activity 계층의 Presentation → Domain → Data 조립을 등록한다.
    ///
    /// 등록 대상은 전부 프로토콜이며, 구현체는 `ActivityData` 가 제공하는 운영 어댑터다.
    /// `MoyaNetworkAdapter` 는 ``DIContainer/configured(modelContext:)`` 가 이미 등록한
    /// 공유 인프라이므로 재등록하지 않고 `resolve` 로만 재사용한다.
    ///
    /// - Note: `LocationProviding` 은 canonical `UMCFoundation.LocationManager` 를 감싼
    ///   ``ActivityData/LocationManagerAdapter`` 를 등록한다. 위치 로직을 feature 모듈에
    ///   재구현하지 않는다.
    /// - Important: 출석·스터디 일정이 `HomeDomain` 의 canonical `ScheduleRepositoryProtocol`
    ///   을 쓰므로 ``DIContainer/registerHomeDependencies(modelContext:)`` 가 **먼저**
    ///   호출돼 있어야 한다.
    ///   같은 엔드포인트를 Activity 에 다시 등록하면 Repository 인스턴스가 두 벌 생기므로
    ///   재등록하지 않고 `resolve` 로만 재사용한다.
    func registerActivityDependencies() {
        registerActivityProviders()
        registerActivityRepositories()
        registerActivityUseCases()
    }

    // MARK: - Provider Seam

    /// 도메인이 요구하는 외부 컨텍스트(사용자 식별자·위치) 제공자를 등록한다.
    private func registerActivityProviders() {
        register(CurrentUserIdProviding.self) {
            UserDefaultsCurrentUserIdProvider()
        }
        register(LocationProviding.self) {
            LocationManagerAdapter()
        }
    }

    // MARK: - Repository

    /// Activity Repository 프로토콜을 등록한다.
    ///
    /// ``ActivityData/AttendanceRepository`` 는 챌린저/운영진 두 프로토콜을 함께 채택한 단일
    /// 구현체다. `resolve` 가 키 단위로 캐싱하므로 두 프로토콜을 각각 생성하면 같은 어댑터를
    /// 감싼 Repository 가 두 벌 생긴다. 구현체를 concrete 키로 한 번 등록하고 두 프로토콜
    /// 키가 그것을 해석하게 해 인스턴스를 하나로 유지한다.
    ///
    /// - Note: 그 대가로 ``DIContainer/resetCache(for:)`` 를 출석 프로토콜 키에만 적용하면
    ///   concrete 키의 기존 인스턴스가 그대로 해석된다. 프로덕션은 로그아웃 시 전체
    ///   ``DIContainer/resetCache()`` 만 쓰므로(`AppRootView`) 실제 경로에는 영향이 없다.
    private func registerActivityRepositories() {
        register(AttendanceRepository.self) {
            AttendanceRepository(adapter: self.resolve(MoyaNetworkAdapter.self))
        }
        register(ChallengerAttendanceRepositoryProtocol.self) {
            self.resolve(AttendanceRepository.self)
        }
        register(OperatorAttendanceRepositoryProtocol.self) {
            self.resolve(AttendanceRepository.self)
        }
        register(StudyRepositoryProtocol.self) {
            StudyRepository(adapter: self.resolve(MoyaNetworkAdapter.self))
        }
        register(MemberRepositoryProtocol.self) {
            MemberRepository(adapter: self.resolve(MoyaNetworkAdapter.self))
        }
    }

    // MARK: - UseCase

    private func registerActivityUseCases() {
        register(ChallengerAttendanceUseCaseProtocol.self) {
            ChallengerAttendanceUseCase(
                repository: self.resolve(ChallengerAttendanceRepositoryProtocol.self),
                scheduleRepository: self.resolve(ScheduleRepositoryProtocol.self),
                locationProvider: self.resolve(LocationProviding.self)
            )
        }
        register(OperatorAttendanceUseCaseProtocol.self) {
            OperatorAttendanceUseCase(
                repository: self.resolve(OperatorAttendanceRepositoryProtocol.self)
            )
        }
        register(OperatorStudyManagementUseCaseProtocol.self) {
            OperatorStudyManagementUseCase(repository: self.resolve(StudyRepositoryProtocol.self))
        }
        register(FetchCurriculumOverviewUseCaseProtocol.self) {
            FetchCurriculumOverviewUseCase(repository: self.resolve(StudyRepositoryProtocol.self))
        }
        register(FetchMembersUseCaseProtocol.self) {
            FetchMembersUseCase(repository: self.resolve(MemberRepositoryProtocol.self))
        }
        register(FetchStudyMembersUseCaseProtocol.self) {
            FetchStudyMembersUseCase(repository: self.resolve(StudyRepositoryProtocol.self))
        }
        register(SearchChallengersUseCaseProtocol.self) {
            SearchChallengersUseCase(repository: self.resolve(MemberRepositoryProtocol.self))
        }
        register(RegisterStudyScheduleUseCaseProtocol.self) {
            RegisterStudyScheduleUseCase(
                scheduleRepository: self.resolve(ScheduleRepositoryProtocol.self),
                studyRepository: self.resolve(StudyRepositoryProtocol.self)
            )
        }
        register(FetchUserIdUseCaseProtocol.self) {
            FetchUserIdUseCase(provider: self.resolve(CurrentUserIdProviding.self))
        }
    }
}
