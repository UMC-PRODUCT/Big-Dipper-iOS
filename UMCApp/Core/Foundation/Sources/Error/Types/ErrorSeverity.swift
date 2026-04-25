//
//  ErrorSeverity.swift
//  UMCFoundation
//
//  Created by jaewon Lee on 1/7/25.
//

import Foundation

/// 에러 심각도
/// - 표시 방식 결정에 사용
public enum ErrorSeverity {
    /// 정보성 알림 (Toast로 표시)
    case info

    /// 경고 (Alert로 표시)
    case warning

    /// 심각 (강제 액션 필요 - 로그아웃 등)
    case critical
}
