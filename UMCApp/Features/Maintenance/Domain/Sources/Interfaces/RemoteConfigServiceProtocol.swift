//
//  RemoteConfigServiceProtocol.swift
//  MaintenanceDomain
//
//  Created by euijjang97 on 7/10/26.
//

/// 원격 킬스위치·강제 업데이트 판정에 필요한 값을 제공하는 서비스 인터페이스.
public protocol RemoteConfigServiceProtocol {
    /// 점검 모드(킬스위치) 상태를 조회한다. 점검이 비활성이면 `nil`을 반환한다.
    func fetchMaintenanceStatus() async -> MaintenanceInfo?
    /// 최소 지원 버전을 조회한다. 콘솔 값이 없으면 `nil`을 반환한다(fail-open).
    func fetchMinimumSupportedVersion() async -> String?
}
