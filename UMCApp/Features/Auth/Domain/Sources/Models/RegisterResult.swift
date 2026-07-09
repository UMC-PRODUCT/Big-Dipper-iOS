/// 소셜 회원가입 결과.
///
/// 토큰 저장은 Repository(Data 레이어)의 TokenStore가 전담하므로(#953 `performOAuthLogin` 선례),
/// Domain은 세션 확립 여부만 노출한다. `sessionEstablished == false`면 서버가 토큰을 내려주지
/// 않은 예외 상황으로, 소셜 재로그인 폴백(`PostRegisterLoginContext`)이 필요하다는 신호다.
public struct RegisterResult: Equatable, Sendable {

    // MARK: - Property

    public let memberId: String
    public let sessionEstablished: Bool

    // MARK: - Init

    public init(memberId: String, sessionEstablished: Bool) {
        self.memberId = memberId
        self.sessionEstablished = sessionEstablished
    }
}
