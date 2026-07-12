import Foundation
import UMCFoundation

/// 일정 분류 UseCase 구현체.
///
/// 정규화된 캐시 키로 캐시를 조회해 hit 시 즉시 반환하고, miss 시 CoreML(로드된 경우) 또는
/// 키워드 매칭으로 분류한다. 강한 규칙(제목에 OT/오티/오리엔테이션/온보딩 포함)은 CoreML
/// 예측 결과보다 우선한다. 분류 결과는 캐시에 저장해 재계산을 피한다.
public final class ClassifyScheduleUseCase: ClassifyScheduleUseCaseProtocol {

    // MARK: - Property

    private let repository: ScheduleClassifierRepositoryProtocol

    // MARK: - Init

    public init(repository: ScheduleClassifierRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute(title: String) async -> ScheduleIconCategory {
        let cacheKey = Self.normalizedCacheKey(from: title)

        guard !cacheKey.isEmpty else { return .general }

        if let cached = repository.getCachedCategory(for: cacheKey) {
            return cached
        }

        let forcedRule = Self.forcedRuleCategory(for: title)

        let result: ScheduleIconCategory
        if repository.isModelLoaded, let mlResult = repository.classifyWithML(title: title) {
            result = forcedRule ?? mlResult
        } else {
            result = forcedRule ?? repository.classifyWithKeywords(title: title)
        }

        repository.cacheCategory(result, for: cacheKey)
        return result
    }

    // MARK: - Private Function

    /// 모델 예측보다 우선해야 하는 강한 규칙 카테고리.
    ///
    /// 예: OT/오리엔테이션/온보딩은 ``ScheduleIconCategory/orientation`` 으로 고정한다.
    private static func forcedRuleCategory(for title: String) -> ScheduleIconCategory? {
        let normalized = title.lowercased()
        let orientationTokens = ["ot", "오티", "오리엔테이션", "온보딩"]
        return orientationTokens.contains(where: normalized.contains) ? .orientation : nil
    }

    /// 캐시 hit 안정성을 위해 제목을 정규화한다 (trim + lowercase + 연속 공백 1칸 축약).
    private static func normalizedCacheKey(from title: String) -> String {
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}
