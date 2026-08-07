import Foundation

/// 알림 분류 Repository 프로토콜.
///
/// CoreML 예측과 키워드 매칭으로 푸시 알림 텍스트를 ``NoticeAlarmType`` 으로 분류한다.
/// 모델 로드는 구현체(Data 계층)가 초기화 시점에 수행하며, 이 프로토콜은 로드 상태
/// (``isModelLoaded``)만 노출한다.
///
/// - Note: 일정 분류(``ScheduleClassifierRepositoryProtocol``)와 달리 캐시가 없다. 푸시 본문은
///   매번 다른 문자열이라 캐시 hit율이 사실상 0이다.
public protocol NoticeClassifierRepositoryProtocol {

    /// CoreML 모델 로드 성공 여부.
    var isModelLoaded: Bool { get }

    /// CoreML 모델로 알림 텍스트를 분류한다. 모델 미로드/예측 실패 시 `nil`을 반환한다.
    func classifyWithML(text: String) -> NoticeAlarmType?

    /// 키워드 매칭으로 알림 텍스트를 분류한다. 매칭되는 키워드가 없으면 ``NoticeAlarmType/info``.
    func classifyWithKeywords(text: String) -> NoticeAlarmType
}
