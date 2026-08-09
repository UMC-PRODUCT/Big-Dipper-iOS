//
//  FetchScheduleCapabilitiesUseCaseProtocol.swift
//  HomeDomain
//
//  Created by euijjang97 on 8/9/26.
//

import Foundation

/// 일정 생성/수정 권한 조회 UseCase 인터페이스
public protocol FetchScheduleCapabilitiesUseCaseProtocol {

    /// - Returns: 생성 가능 여부 · 출석 정책 부착 권한 · 최대 초대 인원
    func execute() async throws -> ScheduleCapabilities
}
