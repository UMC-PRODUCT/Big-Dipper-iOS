//
//  CheckMaintenanceUseCase.swift
//  AppProduct
//
//  원격 점검 상태를 조회하는 UseCase.
//

import Foundation

/// 원격 점검 상태 조회 UseCase.
protocol CheckMaintenanceUseCaseProtocol {

    /// 현재 점검 상태를 조회합니다.
    ///
    /// - Returns: 점검 중이면 `MaintenanceInfo`, 점검 중이 아니거나
    ///   상태 확인에 실패하면 `nil` (fail-open).
    func execute() async -> MaintenanceInfo?
}

/// `RemoteConfigService` 에 조회를 위임하는 기본 구현.
final class CheckMaintenanceUseCase: CheckMaintenanceUseCaseProtocol {

    // MARK: - Property

    private let service: RemoteConfigServiceProtocol

    // MARK: - Init

    init(service: RemoteConfigServiceProtocol) {
        self.service = service
    }

    // MARK: - Function

    func execute() async -> MaintenanceInfo? {
        await service.fetchMaintenanceStatus()
    }
}
