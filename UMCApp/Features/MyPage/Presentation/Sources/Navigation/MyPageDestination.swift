//
//  MyPageDestination.swift
//  MyPagePresentation
//
//  Created by euijjang97 on 8/10/26.
//

import CoreDomain
import MyPageDomain

/// MyPage 탭 안에서 push 되는 화면 목적지.
///
/// 목적지를 App 의 공용 enum 이 아니라 이 모듈이 소유한다 — ``ActivityDestination`` 과 같은 이유로,
/// 공용 enum 은 연관값 때문에 Core → Feature 역방향 의존을 만든다. `CoreRouting.PathStore` 가
/// 타입 소거 경로를 쓰므로 Feature 가 자기 목적지를 들고도 같은 탭 스택에 실린다.
/// 등록까지 탭 루트(``MyPageView``)가 맡으므로 목적지도 화면도 `public` 으로 열 필요가 없다.
enum MyPageDestination: Hashable {

    /// 명함 편집 (#1232).
    ///
    /// 시안의 명함 편집(`Figma 12804:30498`)은 사진·연동 계정·이름·닉네임·학교·활동 이력·
    /// 외부 링크로 프로필 편집 폼과 필드가 1:1 로 같다 — **명함 전용 편집 항목이 따로 없다.**
    /// 명함은 정본 프로필의 순수 파생(`Profile.toMyCard()`)이라 편집할 원본이 프로필뿐이기
    /// 때문이다. 그래서 화면을 새로 만들지 않고 ``MyPageProfileView`` 를 시안 타이틀로 연다.
    ///
    /// - Parameter profileData: 탭 루트가 이미 조회해 둔 프로필 스냅샷. 편집 화면은 이 값을
    ///   편집 시작점으로 삼으므로 목적지가 직접 싣는다 — 재조회하면 카드에 보이던 값과
    ///   어긋난 상태로 편집이 시작될 수 있다.
    case cardEdit(profileData: ProfileData)

    /// 「나의 활동 ・프로젝트」가 여는 활동 이력 목록 (MP-F11, #1228).
    ///
    /// - Parameter activityLogs: 탭 루트가 이미 조회해 둔 `Profile.activityLogs()`. 행 우측
    ///   카운트(`ActivityStat.activityCount`)도 같은 파생을 세므로 목적지가 그 값을 그대로
    ///   싣는다 — 여기서 다시 조회하면 숫자와 목록이 어긋난다(`cardEdit`과 같은 이유).
    case activityLogs([ActivityLog])

    /// 내 활동 게시글 목록 (내가 쓴 글 / 댓글 단 글 / 스크랩).
    ///
    /// - Parameter logType: 진입 시 처음 보여줄 활동 종류. 화면 안에서 세 종류를 전환할 수 있다.
    case myActivePosts(logType: MyActiveLogsType)

    /// 설정 화면 (프로필 링크·시스템 설정·약관·앱 정보·소셜 연동·인증·UMC 채널).
    ///
    /// 프로필이 있어야 의미가 있는 섹션(외부 링크·소셜 연동)은 화면이 직접 조회하므로
    /// 목적지는 스냅샷을 싣지 않는다 — 탭 루트(``MyPageView``)와 같은 방식이다.
    case settings
}
