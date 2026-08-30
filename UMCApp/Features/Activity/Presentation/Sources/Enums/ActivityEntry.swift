//
//  ActivityEntry.swift
//  ActivityPresentation
//
//  Created by euijjang97 on 8/29/26.
//

import CoreDomain

/// 다른 탭이 Activity 탭에 올리는 진입 요청.
///
/// Activity 탭 루트는 모드×섹션(``ActivitySection``)으로 화면을 고르지만, 그 섹션 enum 은
/// 이 모듈 내부 타입이다. 밖에는 "어느 화면으로 가고 싶은지"만 중립적으로 열고, 그게 어느
/// 섹션인지(모드별 `.studyActivity`/`.studyManage`)는 이 모듈이 정한다. 그래서 요청을 올리는
/// 쪽(마이페이지)은 Activity 의 화면 구성을 알 필요가 없다.
///
/// 선례: MyPage 가 명함 진입을 `BusinessCardEntry` 로 올리고 App 셸이 번역한다.
public enum ActivityEntry: Hashable, Sendable {

    // MARK: - Case

    /// 스터디 — 챌린저는 「스터디/활동」, 운영진은 「스터디 관리」.
    case study

    // MARK: - Function

    /// 요청이 가리키는 섹션.
    ///
    /// 모드별 대응은 ``ActivitySection/mapped(to:)`` 가 이미 아는 규칙이라 그대로 쓴다 —
    /// 여기서 모드를 다시 분기하면 같은 표가 두 벌이 된다.
    func section(in mode: ActivityMode) -> ActivitySection {
        switch self {
        case .study: ActivitySection.studyActivity.mapped(to: mode)
        }
    }
}
