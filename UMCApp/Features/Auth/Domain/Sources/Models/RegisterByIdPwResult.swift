/// 이메일(ID/PW) 회원가입 결과.
///
/// 이메일 가입은 서버가 가입과 동시에 항상 토큰을 발급하므로, Repository가 토큰을 저장한 뒤
/// memberId만 반환한다.
public struct RegisterByIdPwResult: Equatable, Sendable {

    // MARK: - Property

    public let memberId: String

    // MARK: - Init

    public init(memberId: String) {
        self.memberId = memberId
    }
}
