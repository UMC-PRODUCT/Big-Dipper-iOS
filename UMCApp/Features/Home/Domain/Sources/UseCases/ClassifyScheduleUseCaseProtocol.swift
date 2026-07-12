import Foundation
import UMCFoundation

/// 일정 제목 기반 분류 UseCase 인터페이스.
public protocol ClassifyScheduleUseCaseProtocol {

    /// 일정 제목을 분석해 적절한 카테고리를 반환한다.
    /// - Parameter title: 일정 제목
    /// - Returns: 분류된 ``ScheduleIconCategory``
    func execute(title: String) async -> ScheduleIconCategory
}
