//
//  CheckMaintenanceUseCase.swift
//  MaintenanceDomain
//
//  Created by euijjang97 on 7/10/26.
//

/// 점검 모드(킬스위치) 활성 여부를 판정하는 UseCase 구현체.
public final class CheckMaintenanceUseCase: CheckMaintenanceUseCaseProtocol {

    // MARK: - Property

    private let service: RemoteConfigServiceProtocol

    // MARK: - Init

    public init(service: RemoteConfigServiceProtocol) {
        self.service = service
    }

    // MARK: - Function

    public func execute() async -> MaintenanceInfo? {
        await service.fetchMaintenanceStatus()
    }
}
