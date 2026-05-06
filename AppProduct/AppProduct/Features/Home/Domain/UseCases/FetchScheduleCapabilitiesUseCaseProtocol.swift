//
//  FetchScheduleCapabilitiesUseCaseProtocol.swift
//  AppProduct
//
//  Created by euijjang97 on 5/6/26.
//

import Foundation

/// 일정 생성/수정 권한 조회 UseCase Protocol
///
/// 일정 생성/수정 화면 진입 시 호출하여 버튼 활성화 / 출석 정책 토글 / 최대 참여자 수를 결정합니다.
///
/// - SeeAlso: ``FetchScheduleCapabilitiesUseCase``, ``ScheduleCapabilities``
protocol FetchScheduleCapabilitiesUseCaseProtocol: Sendable {

    /// 현재 사용자의 일정 생성/수정 권한을 조회합니다.
    ///
    /// - Returns: ``ScheduleCapabilities``
    /// - Throws: 서버 에러 또는 네트워크 에러
    func execute() async throws -> ScheduleCapabilities
}
