import Foundation
import UMCFoundation

/// 일정 분류 Repository 프로토콜.
///
/// CoreML 예측, 키워드 매칭, 분류 결과 캐시 조회/저장 기능을 정의한다. 모델 로드는 구현체
/// (Data 계층)가 초기화 시점에 수행하며, 이 프로토콜은 로드 상태(``isModelLoaded``)만 노출한다.
public protocol ScheduleClassifierRepositoryProtocol {

    /// CoreML 모델 로드 성공 여부.
    var isModelLoaded: Bool { get }

    /// CoreML 모델로 일정 제목을 분류한다. 모델 미로드/예측 실패 시 `nil`을 반환한다.
    func classifyWithML(title: String) -> ScheduleIconCategory?

    /// 키워드 매칭으로 일정 제목을 분류한다. 매칭되는 키워드가 없으면 ``ScheduleIconCategory/general``.
    func classifyWithKeywords(title: String) -> ScheduleIconCategory

    /// 정규화된 캐시 키로 캐시된 분류 결과를 조회한다.
    func getCachedCategory(for cacheKey: String) -> ScheduleIconCategory?

    /// 정규화된 캐시 키에 분류 결과를 저장한다.
    func cacheCategory(_ category: ScheduleIconCategory, for cacheKey: String)
}
