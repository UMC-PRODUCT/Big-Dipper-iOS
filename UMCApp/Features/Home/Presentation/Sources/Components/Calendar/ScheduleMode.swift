//
//  ScheduleMode.swift
//  HomePresentation
//
//  Created by euijjang97 on 8/9/26.
//

import Foundation

/// 홈 일정 캘린더의 표시 모드.
enum ScheduleMode {

    /// 월별 그리드 모드 — 한 달 전체를 7열 달력으로 표시한다.
    case grid

    /// 가로 스크롤 모드 — 한 달의 날짜를 캡슐 리스트로 가로 나열한다.
    case horizon
}
