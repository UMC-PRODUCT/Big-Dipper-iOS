//
//  AttendanceStatus.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/5/26.
//

import Foundation
import SwiftUI

enum AttendanceStatus: String, CaseIterable {
    // rawValue는 API 호환성을 위해 기존값 유지
    case beforeAttendance = "pending"  // 출석 전
    case pendingApproval               // 승인 대기
    case present                       // 출석
    case late                          // 지각
    case absent                        // 결석

    /// 배지/버튼에 표시할 텍스트
    var displayText: String {
        switch self {
        case .beforeAttendance:
            return "출석 전"
        case .pendingApproval:
            return "승인 대기"
        case .present:
            return "출석"
        case .late:
            return "지각"
        case .absent:
            return "결석"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .beforeAttendance:
            return .gray.opacity(0.7)
        case .pendingApproval:
            return .yellow.opacity(0.7)
        case .present:
            return .green.opacity(0.7)
        case .late:
            return .yellow.opacity(0.7)
        case .absent:
            return .red.opacity(0.7)
        }
    }

    var fontColor: Color {
        switch self {
        default:
            return .white
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
    nonisolated init(serverStatus: String) {
        switch serverStatus {
        case "PRESENT", "EXCUSED":
            self = .present
        case "LATE":
            self = .late
        case "ABSENT":
            self = .absent
        case "PENDING":
            self = .beforeAttendance
        case "PRESENT_PENDING", "LATE_PENDING", "EXCUSED_PENDING":
            self = .pendingApproval
        default:
            if serverStatus.hasSuffix("_PENDING") {
                self = .pendingApproval
            } else {
                self = .beforeAttendance
            }
        }
    }
}
