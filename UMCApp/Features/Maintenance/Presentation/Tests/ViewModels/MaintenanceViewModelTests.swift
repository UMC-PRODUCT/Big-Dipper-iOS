import CoreDI
import MaintenanceDomain
import Testing
@testable import MaintenancePresentation

// MARK: - Helpers

@MainActor
private func makeViewModel(
    checkMaintenanceUseCase: CheckMaintenanceUseCaseProtocol? = nil,
    checkForceUpdateUseCase: CheckForceUpdateUseCaseProtocol? = nil
) -> MaintenanceViewModel {
    let checkMaintenanceUseCase = checkMaintenanceUseCase
        ?? StubCheckMaintenanceUseCase(result: nil)
    let checkForceUpdateUseCase = checkForceUpdateUseCase
        ?? StubCheckForceUpdateUseCase(result: false)

    let container = DIContainer()
    container.register(CheckMaintenanceUseCaseProtocol.self) { checkMaintenanceUseCase }
    container.register(CheckForceUpdateUseCaseProtocol.self) { checkForceUpdateUseCase }
    return MaintenanceViewModel(container: container)
}

// MARK: - Tests

@MainActor
@Suite("MaintenanceViewModel — 킬스위치·강제 업데이트 오버레이 판정")
struct MaintenanceViewModelTests {

    @Test("점검이 활성화되면 점검 정보가 노출되고 진입이 차단된다")
    func showsMaintenanceWhenActive() async {
        let info = MaintenanceInfo(
            isActive: true,
            title: "서비스 점검 안내",
            message: "잠시 후 다시 이용해 주세요."
        )
        let viewModel = makeViewModel(
            checkMaintenanceUseCase: StubCheckMaintenanceUseCase(result: info)
        )

        await viewModel.check()

        #expect(viewModel.maintenanceInfo == info)
        #expect(viewModel.overlayKind == .maintenance(info))
    }

    @Test("점검이 비활성이고 업데이트도 불필요하면 오버레이가 없다")
    func noOverlayWhenInactiveAndUpToDate() async {
        let viewModel = makeViewModel()

        await viewModel.check()

        #expect(viewModel.maintenanceInfo == nil)
        #expect(viewModel.overlayKind == nil)
    }

    @Test("서버가 점검을 해제하면 재확인 시 오버레이가 사라진다")
    func clearsWhenServerDisables() async {
        let stub = StubCheckMaintenanceUseCase(
            result: MaintenanceInfo(isActive: true, title: "점검", message: "점검 중")
        )
        let viewModel = makeViewModel(checkMaintenanceUseCase: stub)

        await viewModel.check()
        #expect(viewModel.overlayKind != nil)

        stub.result = nil
        await viewModel.check()
        #expect(viewModel.overlayKind == nil)
    }

    @Test("최소 지원 버전 미달이면 강제 업데이트 오버레이를 노출한다")
    func showsForceUpdateWhenBelowMinimumVersion() async {
        let viewModel = makeViewModel(
            checkForceUpdateUseCase: StubCheckForceUpdateUseCase(result: true)
        )

        await viewModel.check()

        #expect(viewModel.needsForceUpdate == true)
        #expect(viewModel.overlayKind == .forceUpdate)
    }

    @Test("점검과 강제 업데이트가 동시에 감지되면 점검이 우선한다")
    func maintenanceTakesPriorityOverForceUpdate() async {
        let info = MaintenanceInfo(isActive: true, title: "점검", message: "점검 중")
        let viewModel = makeViewModel(
            checkMaintenanceUseCase: StubCheckMaintenanceUseCase(result: info),
            checkForceUpdateUseCase: StubCheckForceUpdateUseCase(result: true)
        )

        await viewModel.check()

        #expect(viewModel.overlayKind == .maintenance(info))
    }
}

// MARK: - Stub

private final class StubCheckMaintenanceUseCase:
    CheckMaintenanceUseCaseProtocol, @unchecked Sendable {
    var result: MaintenanceInfo?

    init(result: MaintenanceInfo?) {
        self.result = result
    }

    func execute() async -> MaintenanceInfo? {
        result
    }
}

private final class StubCheckForceUpdateUseCase:
    CheckForceUpdateUseCaseProtocol, @unchecked Sendable {
    var result: Bool

    init(result: Bool) {
        self.result = result
    }

    func execute() async -> Bool {
        result
    }
}
