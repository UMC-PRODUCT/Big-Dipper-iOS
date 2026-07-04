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
    func execute() async throws -> ProfileData
}
