//
//  MaintenanceViewModelTests.swift
//  AppProductTests
//
//  원격 점검 ViewModel 의 차단/해제/fail-open 동작 검증.
//

@testable import AppProduct
import Testing

@MainActor
struct MaintenanceViewModelTests {

    @Test("점검이 활성화되면 점검 정보가 노출되고 진입이 차단된다")
    func showsMaintenanceWhenActive() async {
        let info = MaintenanceInfo(
            isActive: true,
            title: "서비스 점검 안내",
            message: "잠시 후 다시 이용해 주세요."
        )
        let viewModel = MaintenanceViewModel(
            checkMaintenanceUseCase: StubCheckMaintenanceUseCase(result: info)
        )

        await viewModel.check()

        #expect(viewModel.isUnderMaintenance == true)
        #expect(viewModel.maintenanceInfo == info)
    }

    @Test("점검이 비활성이면 차단하지 않는다")
    func noBlockWhenInactive() async {
        let viewModel = MaintenanceViewModel(
            checkMaintenanceUseCase: StubCheckMaintenanceUseCase(result: nil)
        )

        await viewModel.check()

        #expect(viewModel.isUnderMaintenance == false)
        #expect(viewModel.maintenanceInfo == nil)
    }

    @Test("서버가 점검을 해제하면 재확인 시 차단이 풀린다")
    func clearsWhenServerDisables() async {
        let stub = StubCheckMaintenanceUseCase(
            result: MaintenanceInfo(
                isActive: true,
                title: "점검",
                message: "점검 중"
            )
        )
        let viewModel = MaintenanceViewModel(checkMaintenanceUseCase: stub)

        await viewModel.check()
        #expect(viewModel.isUnderMaintenance == true)

        stub.result = nil
        await viewModel.check()
        #expect(viewModel.isUnderMaintenance == false)
    }
}

// MARK: - Stub

private final class StubCheckMaintenanceUseCase: CheckMaintenanceUseCaseProtocol {
    var result: MaintenanceInfo?

    init(result: MaintenanceInfo?) {
        self.result = result
    }

    func execute() async -> MaintenanceInfo? {
        result
    }
}
