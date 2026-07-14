//
//  FetchUserIdUseCaseProtocol.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 6/26/26.
//

import Foundation

/// 현재 사용자 식별자 조회 UseCase 진입점
public protocol FetchUserIdUseCaseProtocol {

    /// 현재 로그인된 사용자의 식별자를 조회합니다.
    func execute() async throws -> UserID
}
