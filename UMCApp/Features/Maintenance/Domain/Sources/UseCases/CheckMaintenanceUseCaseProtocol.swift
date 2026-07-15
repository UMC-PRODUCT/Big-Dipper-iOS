//
//  CheckMaintenanceUseCaseProtocol.swift
//  MaintenanceDomain
//
//  Created by euijjang97 on 7/10/26.
//

/// 점검 모드(킬스위치) 활성 여부를 판정하는 UseCase 인터페이스.
public protocol CheckMaintenanceUseCaseProtocol {
    func execute() async -> MaintenanceInfo?
}
