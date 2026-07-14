//
//  CurrentUserIdProviding.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 6/26/26.
//

import Foundation

/// 현재 로그인된 사용자의 식별자 제공 seam
///
/// `FetchUserIdUseCase` 가 의존하는 단일 협력자입니다. "현재 사용자 식별자" 는 멤버 관리
/// 데이터 접근과 책임이 다르므로 `MemberRepositoryProtocol` 과 분리된 별도 프로토콜로 둡니다.
/// 구현체는 현재 로컬 세션 저장소를 읽지만(서버 왕복 없음), 향후 서버 기반 조회로 교체될 수
/// 있도록 `async throws` 계약을 유지합니다.
public protocol CurrentUserIdProviding {

    /// 현재 로그인된 사용자의 식별자를 반환합니다.
    func fetchCurrentUserId() async throws -> UserID
}
