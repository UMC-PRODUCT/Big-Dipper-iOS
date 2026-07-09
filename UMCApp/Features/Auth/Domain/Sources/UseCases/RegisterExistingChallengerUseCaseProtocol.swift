/// 기존 챌린저 6자리 코드 등록 UseCase 인터페이스
public protocol RegisterExistingChallengerUseCaseProtocol {
    /// 운영진이 발급한 6자리 코드로 기존 챌린저 기록을 등록한다.
    /// - Parameter code: 운영진 발급 코드
    func execute(code: String) async throws
}
