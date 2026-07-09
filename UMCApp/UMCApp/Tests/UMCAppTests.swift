import Testing
import UMCFoundation
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

    @Test func showSignUpTransitionsToSignUpStateWithAssociatedValues() {
        let viewModel = AppFlowViewModel()
        let context = PostRegisterLoginContext.kakao(accessToken: "token", email: "a@umc.dev")

        viewModel.showSignUp(
            verificationToken: "verify-token",
            email: "a@umc.dev",
            fullName: "홍길동",
            postRegisterLoginContext: context
        )

        #expect(viewModel.state == .signUp(
            verificationToken: "verify-token",
            email: "a@umc.dev",
            fullName: "홍길동",
            postRegisterLoginContext: context
        ))
    }

    @Test func appFlowShowSignUpClosureTransitionsViewModel() {
        let viewModel = AppFlowViewModel()

        viewModel.appFlow.showSignUp("verify-token", nil, nil, nil)

        #expect(viewModel.state == .signUp(
            verificationToken: "verify-token",
            email: nil,
            fullName: nil,
            postRegisterLoginContext: nil
        ))
    }

}
