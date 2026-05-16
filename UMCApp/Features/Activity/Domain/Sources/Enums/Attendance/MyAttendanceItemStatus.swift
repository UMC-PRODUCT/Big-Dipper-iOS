//
//  MyAttendanceItemStatus.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 4/14/26.
//

import Foundation

public enum MyAttendanceItemStatus: Equatable, Sendable {
    case pendingApproval
    case present
    case late
    case absent

    /// 배지/버튼에 표시할 텍스트
    public var text: String {
        switch self {
        case .pendingApproval: return "승인 대기"
        case .present: return "출석"
        case .late: return "지각"
        case .absent: return "결석"
        }
    }
}

extension MyAttendanceItemStatus {
    /// AttendanceStatus에서 변환
    /// - Note: beforeAttendance 상태는 nil 반환 (리스트에 표시 안함)
    public init?(from status: AttendanceStatus) {
        switch status {
        case .pendingApproval: self = .pendingApproval
        case .present: self = .present
        case .late: self = .late
        case .absent: self = .absent
        case .beforeAttendance: return nil
        }
    }
}
