//
//  MockActivityRepository.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/25/26.
//

import Foundation

/// Activity Repository Mock 구현 (개발/테스트용)
final class MockActivityRepository: ActivityRepositoryProtocol {

    func fetchSessions() async throws -> [Session] {
        // 네트워크 지연 시뮬레이션
        try await Task.sleep(for: .milliseconds(500))
        return AttendancePreviewData.sessions
    }

    func fetchCurrentUserId() async throws -> UserID {
        try await Task.sleep(for: .milliseconds(100))
        return AttendancePreviewData.userId
    }
}
