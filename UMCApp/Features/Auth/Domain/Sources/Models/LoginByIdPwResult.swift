//
//  LoginByIdPwResult.swift
//  AuthDomain
//
//  Created by euijjang97 on 7/31/26.
//

/// 이메일(ID/PW) 로그인 결과.
///
/// 이메일 로그인은 서버가 항상 토큰을 발급하므로, Repository가 토큰을 저장한 뒤
/// memberId만 반환한다.
public struct LoginByIdPwResult: Equatable, Sendable {

    // MARK: - Property

    public let memberId: String

    // MARK: - Init

    public init(memberId: String) {
        self.memberId = memberId
    }
}
