import Foundation

/// 알림 분류 UseCase 프로토콜.
///
/// 푸시 알림의 제목·내용을 근거로 알림 보관함에 표시할 ``NoticeAlarmType`` 을 결정한다.
public protocol ClassifyNoticeUseCaseProtocol {

    /// 알림 제목과 내용을 분류한다.
    /// - Parameters:
    ///   - title: 알림 제목
    ///   - content: 알림 본문
    /// - Returns: 결정된 알림 타입
    func execute(title: String, content: String) -> NoticeAlarmType
}
