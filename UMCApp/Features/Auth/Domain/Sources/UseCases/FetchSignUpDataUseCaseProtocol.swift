/// 회원가입 화면에 필요한 학교/약관 데이터 조회 UseCase 인터페이스
public protocol FetchSignUpDataUseCaseProtocol {
    /// 학교 목록을 조회한다.
    func fetchSchools() async throws -> [School]

    /// 특정 종류의 약관을 조회한다.
    /// - Parameter type: 약관 종류
    func fetchTerms(type: TermsType) async throws -> Terms
}
