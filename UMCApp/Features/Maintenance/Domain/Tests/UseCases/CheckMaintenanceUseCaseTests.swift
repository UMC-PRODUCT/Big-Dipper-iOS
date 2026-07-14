//
//  CheckMaintenanceUseCaseTests.swift
//  MaintenanceDomainTests
//
//  Created by euijjang97 on 7/10/26.
//

import Testing
@testable import MaintenanceDomain

// MARK: - Helpers

private func makeUseCase(maintenanceInfo: MaintenanceInfo?) -> CheckMaintenanceUseCase {
    CheckMaintenanceUseCase(
        service: StubRemoteConfigService(stubbedMaintenanceInfo: maintenanceInfo)
    )
}

// MARK: - Tests

@Suite("CheckMaintenanceUseCase — RemoteConfig 점검 상태 판정")
struct CheckMaintenanceUseCaseTests {

    @Test("점검 정보가 없으면 nil을 그대로 반환한다")
    func returnsNilWhenNoMaintenanceInfo() async {
        let useCase = makeUseCase(maintenanceInfo: nil)

        #expect(await useCase.execute() == nil)
    }

    @Test("점검 정보가 있으면 그대로 반환한다")
    func returnsMaintenanceInfoWhenPresent() async {
        let info = MaintenanceInfo(
            isActive: true,
            title: "서비스 점검 안내",
            message: "잠시 후 다시 이용해 주세요."
        )
        let useCase = makeUseCase(maintenanceInfo: info)

        #expect(await useCase.execute() == info)
    }
}
