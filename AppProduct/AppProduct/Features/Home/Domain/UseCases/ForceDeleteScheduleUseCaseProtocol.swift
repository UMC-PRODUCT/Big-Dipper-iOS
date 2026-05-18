//
//  ForceDeleteScheduleUseCaseProtocol.swift
//  AppProduct
//
//  Created by euijjang97 on 5/18/26.
//

import Foundation

/// 출석 기록이 있는 일정을 강제 삭제하는 UseCase Protocol
///
/// 서버 권한 정책상 일정 기수의 SUPER_ADMIN 만 사용할 수 있습니다.
protocol ForceDeleteScheduleUseCaseProtocol {

    /// 강제 삭제를 실행합니다.
    ///
    /// - Parameter scheduleId: 강제 삭제할 일정 ID
    /// - Throws: 서버 에러(403 등) 또는 네트워크 에러
    func execute(scheduleId: Int) async throws
}
