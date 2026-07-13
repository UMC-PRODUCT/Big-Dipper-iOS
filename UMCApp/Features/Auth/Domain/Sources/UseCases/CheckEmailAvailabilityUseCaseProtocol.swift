//
//  CheckEmailAvailabilityUseCaseProtocol.swift
//  AuthDomain
//
//  Created by euijjang97 on 7/9/26.
//

/// 이메일 중복 확인 UseCase 인터페이스
public protocol CheckEmailAvailabilityUseCaseProtocol {
    /// 이메일 중복 가입 여부를 확인한다.
    /// - Parameter email: 확인할 이메일 주소
    /// - Returns: 사용 가능하면 true
    func execute(email: String) async throws -> Bool
}
