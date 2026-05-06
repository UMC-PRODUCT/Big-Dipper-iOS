//
//  ScheduleCapabilitiesRepositoryProtocol.swift
//  AppProduct
//
//  Created by euijjang97 on 5/6/26.
//

import Foundation

/// 일정 생성/수정 권한 조회 Repository Protocol
///
/// `GET /api/v2/schedules/capabilities` 호출을 추상화합니다.
/// 캐싱 전략은 호출처(ViewModel/데코레이터)가 결정합니다 — 본 Repository 는 매번 fresh 호출만 수행합니다.
///
/// - SeeAlso: ``ScheduleCapabilitiesRepository``, ``FetchScheduleCapabilitiesUseCaseProtocol``
protocol ScheduleCapabilitiesRepositoryProtocol: Sendable {

    /// 현재 사용자의 일정 생성/수정 권한을 조회합니다.
    ///
    /// - Returns: ``ScheduleCapabilities`` (권한 플래그 + 최대 초대 인원)
    /// - Throws: 서버 에러 또는 네트워크 에러
    func fetchCapabilities() async throws -> ScheduleCapabilities
}
