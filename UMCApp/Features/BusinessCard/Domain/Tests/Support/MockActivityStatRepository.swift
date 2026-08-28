//
//  MockActivityStatRepository.swift
//  BusinessCardDomainTests
//
//  Created by One on 8/16/26.
//

import Foundation
@testable import BusinessCardDomain

final class MockActivityStatRepository: ActivityStatRepositoryProtocol, @unchecked Sendable {

    // MARK: - Stub

    /// 잘림 표기(`"50+"`)까지 실어야 해서 String (프로토콜과 동일).
    var studyCountResult: Result<String, Error> = .failure(MockError.notStubbed)
    /// 서버 `totalElements` 원본 통과라 String (프로토콜과 동일).
    var bookmarkCountResult: Result<String, Error> = .failure(MockError.notStubbed)
    var activityCountResult: Result<Int, Error> = .failure(MockError.notStubbed)

    // MARK: - ActivityStatRepositoryProtocol

    func fetchStudyCount() async throws -> String {
        try studyCountResult.get()
    }

    func fetchBookmarkCount() async throws -> String {
        try bookmarkCountResult.get()
    }

    func fetchActivityCount() async throws -> Int {
        try activityCountResult.get()
    }
}
