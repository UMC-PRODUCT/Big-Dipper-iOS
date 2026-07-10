import Testing
@testable import MaintenanceDomain

// MARK: - Helpers

private func makeUseCase(
    minimumVersion: String?,
    currentVersion: String
) -> CheckForceUpdateUseCase {
    CheckForceUpdateUseCase(
        service: StubRemoteConfigService(stubbedMinimumVersion: minimumVersion),
        currentVersion: currentVersion
    )
}

// MARK: - Tests

@Suite("CheckForceUpdateUseCase — RemoteConfig 최소 지원 버전 기반 강제 업데이트 판정")
struct CheckForceUpdateUseCaseTests {

    @Test("콘솔 값이 없으면 차단하지 않는다 (fail-open)")
    func noBlockWhenMinimumVersionMissing() async {
        let useCase = makeUseCase(minimumVersion: nil, currentVersion: "1.7.0")

        #expect(await useCase.execute() == false)
    }

    @Test("현재 버전이 최소 지원 버전과 같으면 차단하지 않는다")
    func noBlockWhenVersionEqual() async {
        let useCase = makeUseCase(minimumVersion: "1.7.0", currentVersion: "1.7.0")

        #expect(await useCase.execute() == false)
    }

    @Test("패치 버전이 낮으면 차단한다 (1.7.0 < 1.7.1)")
    func blocksWhenPatchVersionLower() async {
        let useCase = makeUseCase(minimumVersion: "1.7.1", currentVersion: "1.7.0")

        #expect(await useCase.execute() == true)
    }

    @Test("마이너 버전이 낮으면 차단한다 (1.7.5 < 1.8.0)")
    func blocksWhenMinorVersionLower() async {
        let useCase = makeUseCase(minimumVersion: "1.8.0", currentVersion: "1.7.5")

        #expect(await useCase.execute() == true)
    }

    @Test("현재 버전이 더 높으면 차단하지 않는다 — 심사/테스터 빌드 통과 경로")
    func noBlockWhenCurrentVersionHigher() async {
        let useCase = makeUseCase(minimumVersion: "1.7.1", currentVersion: "1.8.0")

        #expect(await useCase.execute() == false)
    }

    @Test("자리 수가 달라도 빈 자리를 0 으로 채워 비교한다 (1.7 == 1.7.0)")
    func padsMissingComponentsWithZero() async {
        let equalCase = makeUseCase(minimumVersion: "1.7.0", currentVersion: "1.7")
        let lowerCase = makeUseCase(minimumVersion: "1.7.1", currentVersion: "1.7")

        #expect(await equalCase.execute() == false)
        #expect(await lowerCase.execute() == true)
    }

    @Test("자리별 숫자 비교라 1.10.0 은 1.9.0 보다 높다")
    func comparesNumericallyPerComponent() async {
        let useCase = makeUseCase(minimumVersion: "1.9.0", currentVersion: "1.10.0")

        #expect(await useCase.execute() == false)
    }

    @Test("숫자가 아닌 콘솔 값은 0 으로 간주해 오차단하지 않는다")
    func treatsMalformedConsoleValueAsZero() async {
        let useCase = makeUseCase(minimumVersion: "abc", currentVersion: "1.7.0")

        #expect(await useCase.execute() == false)
    }
}
