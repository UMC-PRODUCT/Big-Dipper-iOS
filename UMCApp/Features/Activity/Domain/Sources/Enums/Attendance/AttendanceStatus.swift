//
//  AttendanceStatus.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 4/14/26.
//

import Foundation

public enum AttendanceStatus: String, CaseIterable {
    case beforeAttendance = "pending"
    case pendingApproval
    case present
    case late
    case absent

    /// 배지/버튼에 표시할 텍스트
    public var displayText: String {
        switch self {
        case .beforeAttendance: return "출석 전"
        case .pendingApproval: return "승인 대기"
        case .present: return "출석"
        case .late: return "지각"
        case .absent: return "결석"
        }
    }
}

// MARK: - Server Status Mapping
extension AttendanceStatus {
    /// 서버 API 상태 문자열 → Domain enum 변환
    ///
    /// - Parameter serverStatus: 서버 응답 status 필드
    ///   (e.g., "PRESENT", "LATE", "ABSENT", "PENDING",
    ///    "PRESENT_PENDING", "LATE_PENDING", "EXCUSED",
    ///    "EXCUSED_PENDING")
    public init(serverStatus: String) {
        switch serverStatus {
        case "PRESENT", "EXCUSED": self = .present
        case "LATE": self = .late
        case "ABSENT": self = .absent
        case "PENDING": self = .beforeAttendance
        case "PRESENT_PENDING", "LATE_PENDING", "EXCUSED_PENDING": self = .pendingApproval
        default:
            if serverStatus.hasSuffix("_PENDING") {
                self = .pendingApproval
            } else {
                self = .beforeAttendance
            }
        }
    }
}
