//
//  DIContainer+Home.swift
//  UMCApp
//
//  Created by euijjang97 on 7/9/26.
//

import CoreDI
import CoreDomain
import CoreNetwork
import HomeData
import HomeDomain
import NoticeDomain
import SwiftData

extension DIContainer {
    /// - Parameter modelContext: 기수 매핑 로컬 저장소(SwiftData)에 주입할 컨텍스트.
    func registerHomeDependencies(modelContext: ModelContext) {
        register(ChallengerGenRepositoryProtocol.self) {
            ChallengerGenRepository(modelContext: modelContext)
        }
        register(HomeRepositoryProtocol.self) {
            HomeRepository(
                adapter: self.resolve(MoyaNetworkAdapter.self),
                memberProfileRepository: self.resolve(MemberProfileRepositoryProtocol.self)
            )
        }
        register(FetchHomeProfileUseCaseProtocol.self) {
            FetchHomeProfileUseCase(repository: self.resolve(HomeRepositoryProtocol.self))
        }
        register(FetchRecentNoticesUseCaseProtocol.self) {
            FetchRecentNoticesUseCase(repository: self.resolve(NoticeRepositoryProtocol.self))
        }
        register(ScheduleRepositoryProtocol.self) {
            ScheduleRepository(adapter: self.resolve(MoyaNetworkAdapter.self))
        }
        register(FetchSchedulesUseCaseProtocol.self) {
            FetchSchedulesUseCase(repository: self.resolve(ScheduleRepositoryProtocol.self))
        }
        register(FetchScheduleDetailUseCaseProtocol.self) {
            FetchScheduleDetailUseCase(repository: self.resolve(ScheduleRepositoryProtocol.self))
        }
        register(RegisterFCMTokenUseCaseProtocol.self) {
            RegisterFCMTokenUseCase(repository: self.resolve(HomeRepositoryProtocol.self))
        }
        register(NoticeClassifierRepositoryProtocol.self) {
            NoticeClassifierRepository()
        }
        register(ClassifyNoticeUseCaseProtocol.self) {
            ClassifyNoticeUseCase(
                repository: self.resolve(NoticeClassifierRepositoryProtocol.self)
            )
        }
        register(ScheduleClassifierRepositoryProtocol.self) {
            ScheduleClassifierRepository()
        }
        register(ClassifyScheduleUseCaseProtocol.self) {
            ClassifyScheduleUseCase(
                repository: self.resolve(ScheduleClassifierRepositoryProtocol.self)
            )
        }
    }
}
