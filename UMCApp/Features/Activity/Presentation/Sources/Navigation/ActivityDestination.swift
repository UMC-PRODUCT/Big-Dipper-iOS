//
//  ActivityDestination.swift
//  ActivityPresentation
//
//  Created by 이재원 on 7/30/26.
//

/// Activity 탭 안에서 push 되는 화면 목적지.
///
/// ## 왜 Feature 가 목적지를 소유하는가
///
/// 모든 탭의 목적지를 공유 모듈의 단일 enum 에 모으면, 그 enum 이 있는 모듈이 각 Feature 의
/// 도메인 타입(연관값)에 의존하게 된다. 즉 Core → Feature 역방향 의존이 생긴다.
/// `CoreRouting.PathStore` 는 타입 소거 경로를 제공하므로, 각 Feature 가 자기 목적지 타입을
/// 자기 모듈에 두고도 같은 탭 스택에 실릴 수 있다.
///
/// - Important: 식별자는 전 레이어 `String` 이다(절대 규칙 #2). 레거시는 `Int` 로 들고 다녔고,
///   push 직전의 `Int(group.serverID)` 변환은 **타입 변환만이 아니라 낙관적 삽입 placeholder
///   (`new_` 접두사) 를 걸러내는 필터이기도 했다**. `String` 통일로 그 변환이 사라졌으므로,
///   걸러내는 책임은 `OperatorStudyManagementViewModel.canRegisterSchedule(for:)` 의
///   `isPersistedServerGroup` 판정이 이어받는다. 새 진입점을 만들 때 이 판정을 빠뜨리면
///   서버에 없는 그룹 ID 가 목적지로 넘어간다.
public enum ActivityDestination: Hashable, Sendable {

    /// 스터디 일정 등록 화면.
    ///
    /// - Parameters:
    ///   - studyName: 헤더에 표시할 스터디 그룹 이름
    ///   - studyGroupId: 일정을 등록할 스터디 그룹 식별자 (서버에 저장된 그룹만)
    case studyScheduleRegistration(studyName: String, studyGroupId: String)

    /// 운영진의 단일 일정 출석 현황 화면.
    ///
    /// 목적지 화면(`OperatorAttendanceDetailView`)은 연결되어 있다. 다만 레거시에서 이 경로를
    /// 만들던 진입점(출석 현황 목록의 행 탭)은 아직 이 경로를 쓰지 않아 생산자가 없다.
    case attendanceDetail(scheduleId: String)
}
