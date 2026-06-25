//
//  UpdateMyPageProfileLinksUseCaseProtocol.swift
//  MyPageDomain
//
//  Created by euijjang97 on 5/10/26.
//

import Foundation

/// 프로필 외부 링크 수정 UseCase Protocol
///
/// 소셜/포트폴리오 링크 배열을 서버에 반영하고 갱신된 프로필을 반환합니다.
public protocol UpdateMyPageProfileLinksUseCaseProtocol {
    /// 프로필 링크를 서버에 반영합니다.
    ///
    /// - Parameter profileLinks: 수정할 프로필 링크 배열
    /// - Returns: 서버 반영 후 갱신된 `ProfileData`
    func execute(
        profileLinks: [ProfileLink]
    ) async throws -> ProfileData
}
