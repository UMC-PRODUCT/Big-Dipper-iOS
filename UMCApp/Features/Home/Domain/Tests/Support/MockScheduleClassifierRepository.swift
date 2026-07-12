import Foundation
import UMCFoundation
@testable import HomeDomain

/// `ScheduleClassifierRepositoryProtocol`의 테스트용 Mock 구현체.
///
/// CoreML/키워드 분류 결과를 미리 주입하고, 캐시는 인메모리 딕셔너리(`cache`)를 테스트에서
/// 직접 읽고 씀으로써 정규화된 캐시 키 저장 여부를 검증할 수 있습니다.
final class MockScheduleClassifierRepository: ScheduleClassifierRepositoryProtocol, @unchecked Sendable {

    var isModelLoaded = false
    var mlResult: ScheduleIconCategory?
    var keywordResult: ScheduleIconCategory = .general
    var cache: [String: ScheduleIconCategory] = [:]

    private(set) var classifyWithMLCallCount = 0
    private(set) var classifyWithKeywordsCallCount = 0

    func classifyWithML(title: String) -> ScheduleIconCategory? {
        classifyWithMLCallCount += 1
        return mlResult
    }

    func classifyWithKeywords(title: String) -> ScheduleIconCategory {
        classifyWithKeywordsCallCount += 1
        return keywordResult
    }

    func getCachedCategory(for cacheKey: String) -> ScheduleIconCategory? {
        cache[cacheKey]
    }

    func cacheCategory(_ category: ScheduleIconCategory, for cacheKey: String) {
        cache[cacheKey] = category
    }
}
