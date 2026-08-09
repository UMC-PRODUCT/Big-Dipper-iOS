//
//  ScheduleCapabilitiesRepositoryProtocol.swift
//  HomeDomain
//
//  Created by euijjang97 on 8/9/26.
//

import Foundation

/// 일정 생성/수정 권한 조회 인터페이스.
///
/// 권한은 직책 변경으로 언제든 바뀔 수 있어 이 계층은 매번 서버 값을 그대로 조회한다.
/// 캐싱이 필요하면 호출처가 결정한다.
public protocol ScheduleCapabilitiesRepositoryProtocol {

    /// 현재 사용자의 일정 생성/수정 권한을 조회한다.
    func fetchCapabilities() async throws -> ScheduleCapabilities
}
