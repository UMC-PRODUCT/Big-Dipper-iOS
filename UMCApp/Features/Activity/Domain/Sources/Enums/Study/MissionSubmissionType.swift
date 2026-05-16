//
//  MissionSubmissionType.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/11/26.
//

import Foundation

/// 미션 제출 방식
///
/// 링크 제출 또는 완료 확인만 선택할 수 있습니다.
/// 아이콘 등 UI 매핑은 Presentation 레이어 extension으로 제공됩니다.
public enum MissionSubmissionType: String, CaseIterable {
    case link = "링크"
    case completeOnly = "완료만"
}
