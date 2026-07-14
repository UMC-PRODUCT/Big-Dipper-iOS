//
//  FetchMyPageProfileUseCaseProtocol.swift
//  MyPageDomain
//
//  Created by euijjang97 on 5/10/26.
//

import Foundation
/// 내 프로필 조회  UseCase Protocol
///
/// MyPage에서 내 프로필 정보를 조회합니다
public protocol FetchMyPageProfileUseCaseProtocol {

    /// 내 프로필을 조회한다.
    /// - Parameter forceRefresh: `true`이면 세션 프로필 캐시를 우회해 서버에서 새로 조회한다.
    func execute(forceRefresh: Bool) async throws -> ProfileData
}

extension FetchMyPageProfileUseCaseProtocol {

    /// 내 프로필을 조회한다 (캐시 허용 기본 경로, `forceRefresh: false`와 동일).
    public func execute() async throws -> ProfileData {
        try await execute(forceRefresh: false)
    }
}
