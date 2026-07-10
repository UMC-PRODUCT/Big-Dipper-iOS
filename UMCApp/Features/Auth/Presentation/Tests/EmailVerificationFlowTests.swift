import Testing
import Foundation
import AuthDomain
@testable import AuthPresentation

@MainActor
@Suite("EmailVerificationFlow — 발송/검증/재전송")
struct EmailVerificationFlowRequestTests {

    @Test("인증번호 발송 성공 시 emailVerificationId가 저장되고 purpose가 그대로 전달된다")
    func requestEmailVerificationStoresIdAndPassesPurpose() async throws {
        let sendUseCase = MockSendEmailVerificationUseCase()
        sendUseCase.result = .success("verify-id-1")
        let flow = makeFlow(purpose: .passwordReset, sendEmailVerificationUseCase: sendUseCase)
        flow.email = "member@umc.dev"

        try await flow.requestEmailVerification()

        #expect(sendUseCase.callCount == 1)
        #expect(sendUseCase.receivedEmail == "member@umc.dev")
        #expect(sendUseCase.receivedPurpose == .passwordReset)
        #expect(flow.emailVerificationId == "verify-id-1")
    }

    @Test("emailVerificationId가 없으면 verifyEmailCode는 false를 반환하고 아무 것도 검증하지 않는다")
    func verifyEmailCodeWithoutIdReturnsFalse() async throws {
        let verifyUseCase = MockVerifyEmailCodeUseCase()
        let flow = makeFlow(verifyEmailCodeUseCase: verifyUseCase)

        let didVerify = try await flow.verifyEmailCode("123456")

        #expect(didVerify == false)
        #expect(verifyUseCase.callCount == 0)
        #expect(flow.isEmailVerified == false)
    }

    @Test("인증번호 검증 성공 시 true를 반환하고 토큰이 저장되며 isEmailVerified가 true가 된다")
    func verifyEmailCodeSucceedsAfterRequest() async throws {
        let sendUseCase = MockSendEmailVerificationUseCase()
        sendUseCase.result = .success("verify-id-1")
        let verifyUseCase = MockVerifyEmailCodeUseCase()
        verifyUseCase.result = .success("verify-token-1")
        let flow = makeFlow(
            sendEmailVerificationUseCase: sendUseCase,
            verifyEmailCodeUseCase: verifyUseCase
        )
        flow.email = "member@umc.dev"
        try await flow.requestEmailVerification()

        let didVerify = try await flow.verifyEmailCode("123456")

        #expect(didVerify == true)
        #expect(flow.isEmailVerified == true)
        #expect(flow.emailVerificationToken == "verify-token-1")
    }

    @Test("emailVerificationId가 없으면 resendEmailVerification은 아무 것도 하지 않는다")
    func resendWithoutIdNoOps() async throws {
        let resendUseCase = MockResendEmailVerificationUseCase()
        let flow = makeFlow(resendEmailVerificationUseCase: resendUseCase)

        try await flow.resendEmailVerification()

        #expect(resendUseCase.callCount == 0)
    }

    @Test("인증번호 발송 후 재전송하면 동일한 emailVerificationId로 재전송 UseCase가 호출된다")
    func resendAfterRequestCallsUseCaseWithSameId() async throws {
        let sendUseCase = MockSendEmailVerificationUseCase()
        sendUseCase.result = .success("verify-id-1")
        let resendUseCase = MockResendEmailVerificationUseCase()
        resendUseCase.result = .success(())
        let flow = makeFlow(
            sendEmailVerificationUseCase: sendUseCase,
            resendEmailVerificationUseCase: resendUseCase
        )
        flow.email = "member@umc.dev"
        try await flow.requestEmailVerification()

        try await flow.resendEmailVerification()

        #expect(resendUseCase.callCount == 1)
        #expect(resendUseCase.receivedEmailVerificationId == "verify-id-1")
    }

    @Test("발송 요청이 진행 중이면 재진입 호출은 API를 다시 호출하지 않는다")
    func duplicateRequestWhileInFlightIsIgnored() async throws {
        let slowUseCase = SlowSendEmailVerificationUseCase(delayNanoseconds: 50_000_000)
        let flow = makeFlow(sendEmailVerificationUseCase: slowUseCase)
        flow.email = "member@umc.dev"

        let first = Task { try await flow.requestEmailVerification() }
        await Task.yield()

        try await flow.requestEmailVerification()
        try await first.value

        #expect(slowUseCase.callCount == 1)
    }
}

@MainActor
@Suite("EmailVerificationFlow — 이메일 변경 감지")
struct EmailVerificationFlowEmailChangeTests {

    @Test("이메일이 바뀌지 않았다면 재호출해도 인증 상태가 유지된다")
    func handleEmailChangedNoOpsWhenEmailUnchanged() async throws {
        let flow = try await makeVerifiedFlow()
        // 최초 호출 시점엔 스냅샷이 아직 비어 있으므로(어떤 이메일과 비교해도 다름) 리셋된다.
        flow.handleEmailChanged()
        #expect(flow.isEmailVerified == false)

        try await flow.requestEmailVerification()
        try await flow.verifyEmailCode("123456")
        #expect(flow.isEmailVerified == true)

        // 이메일을 바꾸지 않고 재호출 — 스냅샷과 동일하므로 리셋되지 않아야 한다.
        flow.handleEmailChanged()

        #expect(flow.isEmailVerified == true)
    }

    @Test("이메일이 실제로 바뀌면 인증 상태가 초기화된다")
    func handleEmailChangedResetsWhenEmailActuallyChanges() async throws {
        let flow = try await makeVerifiedFlow()

        flow.email = "changed@umc.dev"
        flow.handleEmailChanged()

        #expect(flow.isEmailVerified == false)
        #expect(flow.emailVerificationId == nil)
        #expect(flow.emailVerificationToken == nil)
    }

    @Test("이메일 변경으로 인한 리셋은 onReset 훅을 호출한다")
    func handleEmailChangedInvokesOnResetHook() async throws {
        let flow = try await makeVerifiedFlow()
        var onResetCallCount = 0
        flow.onReset = { onResetCallCount += 1 }

        flow.email = "changed@umc.dev"
        flow.handleEmailChanged()

        #expect(onResetCallCount == 1)
    }
}

@MainActor
@Suite("EmailVerificationFlow — resetEmailVerification")
struct EmailVerificationFlowResetTests {

    @Test("resetEmailVerification은 인증 상태를 모두 초기화하고 onReset을 호출한다")
    func resetClearsStateAndInvokesHook() async throws {
        let flow = try await makeVerifiedFlow()
        var onResetCallCount = 0
        flow.onReset = { onResetCallCount += 1 }

        flow.resetEmailVerification()

        #expect(flow.isEmailVerified == false)
        #expect(flow.emailVerificationId == nil)
        #expect(flow.emailVerificationToken == nil)
        #expect(onResetCallCount == 1)
    }

    @Test("onReset이 설정되지 않아도 resetEmailVerification은 안전하게 동작한다")
    func resetWithoutHookDoesNotCrash() async throws {
        let flow = try await makeVerifiedFlow()

        flow.resetEmailVerification()

        #expect(flow.isEmailVerified == false)
    }
}

// MARK: - Helpers

@MainActor
private func makeFlow(
    purpose: EmailVerificationPurpose = .register,
    sendEmailVerificationUseCase: SendEmailVerificationUseCaseProtocol? = nil,
    verifyEmailCodeUseCase: VerifyEmailCodeUseCaseProtocol? = nil,
    resendEmailVerificationUseCase: ResendEmailVerificationUseCaseProtocol? = nil
) -> EmailVerificationFlow {
    EmailVerificationFlow(
        purpose: purpose,
        sendEmailVerificationUseCase: sendEmailVerificationUseCase
            ?? MockSendEmailVerificationUseCase(),
        verifyEmailCodeUseCase: verifyEmailCodeUseCase ?? MockVerifyEmailCodeUseCase(),
        resendEmailVerificationUseCase: resendEmailVerificationUseCase
            ?? MockResendEmailVerificationUseCase()
    )
}

/// 이메일 인증까지 완료한 상태의 플로우를 만든다.
@MainActor
private func makeVerifiedFlow(
    email: String = "member@umc.dev"
) async throws -> EmailVerificationFlow {
    let sendUseCase = MockSendEmailVerificationUseCase()
    sendUseCase.result = .success("verify-id-1")
    let verifyUseCase = MockVerifyEmailCodeUseCase()
    verifyUseCase.result = .success("verify-token-1")

    let flow = makeFlow(
        sendEmailVerificationUseCase: sendUseCase,
        verifyEmailCodeUseCase: verifyUseCase
    )
    flow.email = email
    try await flow.requestEmailVerification()
    try await flow.verifyEmailCode("123456")

    return flow
}

// MARK: - Mocks — UseCase

private final class MockSendEmailVerificationUseCase: SendEmailVerificationUseCaseProtocol,
    @unchecked Sendable {
    enum MockError: Error, Equatable { case notStubbed }

    var result: Result<String, Error> = .failure(MockError.notStubbed)
    private(set) var callCount = 0
    private(set) var receivedEmail: String?
    private(set) var receivedPurpose: EmailVerificationPurpose?

    func execute(email: String, purpose: EmailVerificationPurpose) async throws -> String {
        callCount += 1
        receivedEmail = email
        receivedPurpose = purpose
        return try result.get()
    }
}

private final class MockVerifyEmailCodeUseCase: VerifyEmailCodeUseCaseProtocol,
    @unchecked Sendable {
    enum MockError: Error, Equatable { case notStubbed }

    var result: Result<String, Error> = .failure(MockError.notStubbed)
    private(set) var callCount = 0

    func execute(emailVerificationId: String, verificationCode: String) async throws -> String {
        callCount += 1
        return try result.get()
    }
}

private final class MockResendEmailVerificationUseCase: ResendEmailVerificationUseCaseProtocol,
    @unchecked Sendable {
    enum MockError: Error, Equatable { case notStubbed }

    var result: Result<Void, Error> = .failure(MockError.notStubbed)
    private(set) var callCount = 0
    private(set) var receivedEmailVerificationId: String?

    func execute(emailVerificationId: String) async throws {
        callCount += 1
        receivedEmailVerificationId = emailVerificationId
        _ = try result.get()
    }
}

/// 재진입 가드 검증을 위해 인위적인 지연을 주는 인증 발송 UseCase.
private final class SlowSendEmailVerificationUseCase: SendEmailVerificationUseCaseProtocol,
    @unchecked Sendable {
    private let delayNanoseconds: UInt64
    private let lock = NSLock()
    private var _callCount = 0

    var callCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _callCount
    }

    init(delayNanoseconds: UInt64) {
        self.delayNanoseconds = delayNanoseconds
    }

    func execute(email: String, purpose: EmailVerificationPurpose) async throws -> String {
        lock.lock()
        _callCount += 1
        lock.unlock()
        try await Task.sleep(nanoseconds: delayNanoseconds)
        return "verify-id-slow"
    }
}
