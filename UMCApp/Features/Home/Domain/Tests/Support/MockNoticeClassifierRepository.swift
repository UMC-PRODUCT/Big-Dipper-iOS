import Foundation
@testable import HomeDomain

/// `NoticeClassifierRepositoryProtocol`의 테스트용 Mock 구현체.
final class MockNoticeClassifierRepository: NoticeClassifierRepositoryProtocol, @unchecked Sendable {

    var isModelLoaded = false
    var mlResult: NoticeAlarmType?
    var keywordResult: NoticeAlarmType = .info

    private(set) var classifyWithMLCallCount = 0
    private(set) var classifyWithKeywordsCallCount = 0
    private(set) var receivedText: String?

    func classifyWithML(text: String) -> NoticeAlarmType? {
        classifyWithMLCallCount += 1
        receivedText = text
        return mlResult
    }

    func classifyWithKeywords(text: String) -> NoticeAlarmType {
        classifyWithKeywordsCallCount += 1
        receivedText = text
        return keywordResult
    }
}
