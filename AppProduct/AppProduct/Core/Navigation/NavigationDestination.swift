//
//  NavigationDestination.swift
//  AppProduct
//
//  Created by euijjang97 on 1/8/26.
//

import Foundation

// MARK: - NavigationDestination 사용 예시

/// NavigationDestination은 앱 내 모든 화면 목적지를 타입 세이프하게 정의하는 enum입니다.
/// 각 피처별로 중첩 enum을 사용하여 화면을 그룹화합니다.
///
/// ## 새로운 화면 추가 방법
///
/// ### 1. 피처 내 새 화면 추가
/// ```swift
/// enum Auth: Hashable {
///     case test
///     case login           // 새 화면 추가
///     case signup(email: String)  // 연관값과 함께 추가
/// }
/// ```
///
/// ### 2. 새로운 피처 그룹 추가
/// ```swift
/// enum NavigationDestination: Hashable {
///     // 기존 피처들
///     case auth(Auth)
///     case home(Home)
///
///     // 새 피처 추가
///     enum Profile: Hashable {
///         case detail(userId: String)
///         case settings
///     }
///     case profile(Profile)
/// }
/// ```
///
/// ### 3. NavigationRouter에서 사용
/// ```swift
/// router.push(to: .auth(.login))
/// router.push(to: .home(.test))
/// router.push(to: .profile(.detail(userId: "123")))
/// ```

enum NavigationDestination: Hashable {

    /// 인증(Auth) 관련 화면 목적지
    enum Auth: Hashable {
        case test
        /// ID/PW 로그인 입력 화면
        case loginByIdPw
        /// ID/PW 회원가입 화면
        case signUpByIdPw
    }

    /// 홈(Home) 관련 화면 목적지
    enum Home: Hashable {
        /// 알림 히스토리
        case alarmHistory
        /// 일정 등록
        case registrationSchedule
        /// 일정 상세 (scheduleId: 일정 ID)
        case detailSchedule(scheduleId: Int)
        /// 홈에서 진입하는 공지 상세
        case detailNotice(detailItem: NoticeDetail)
    }

    /// 공지사항(Notice) 관련 화면 목적지
    enum Notice: Hashable {
        /// 공지 상세
        case detail(detailItem: NoticeDetail)
        /// 공지 작성/편집
        case editor(mode: NoticeEditorMode, selectedGisuId: Int?)
        /// 운영진 공지
        case staffNotice
    }

    /// 커뮤니티(Community) 관련 화면 목적지
    enum Community: Hashable {
        /// 게시글 상세
        case detail(postId: Int)
        /// 게시글 작성/수정 (editItem: 수정할 게시글, nil이면 작성 모드)
        case post(editItem: CommunityItemModel? = nil)
    }

    /// 마이페이지(MyPage) 관련 화면 목적지
    enum MyPage: Hashable {
        /// 내 정보 수정
        case myInfo(profileData: ProfileData)
        /// 내 활동 게시글 목록
        case myActivePosts(type: MyActiveLogsType)
        /// 프로덕트 팀 소개
        case productTeamIntroduction
    }

    /// 활동(Activity) 관련 화면 목적지
    enum Activity: Hashable {
        /// 스터디 일정 등록 (studyName: 스터디명, studyGroupId: 스터디 그룹 ID)
        case studyScheduleRegistration(studyName: String, studyGroupId: Int)
        /// 운영진 출석 현황 목록 (Schedule V2)
        ///
        /// 필터: 상태(`AttendanceStatusV2`) + 기간 (`from`/`to`).
        /// `canCreateAttendanceRequiredSchedule = true` 인 사용자만 진입 가능 (AC-E1).
        case attendanceList
        /// 운영진 단일 일정 출석 현황 (Schedule V2)
        ///
        /// 진입 경로: 출석 현황 목록 → 행 탭, 또는 일정 상세 → "출석 현황" 버튼.
        case attendanceDetail(scheduleId: Int)
    }

    case auth(Auth)
    case home(Home)
    case notice(Notice)
    case community(Community)
    case myPage(MyPage)
    case activity(Activity)
}
