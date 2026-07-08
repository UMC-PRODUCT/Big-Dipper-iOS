import Testing
@testable import UMCApp

struct UMCAppTests {

    @Test func initialStateIsBootstrap() {
        let viewModel = AppFlowViewModel()

        #expect(viewModel.state == .bootstrap)
    }

    @Test func reenteringSameStateIsNoop() {
        let viewModel = AppFlowViewModel()

        viewModel.showLogin()
        #expect(viewModel.state == .login)

        viewModel.showLogin()
        #expect(viewModel.state == .login)
    }

    @Test func stateTransitionsUpdateAccordingly() {
        let viewModel = AppFlowViewModel()

        viewModel.showLogin()
        #expect(viewModel.state == .login)

        viewModel.showMain()
        #expect(viewModel.state == .main)

        viewModel.logout()
        #expect(viewModel.state == .login)
    }

}
