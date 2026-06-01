//
//  NavigationModifier.swift
//  AppProduct
//
//  Created by euijjang97 on 1/12/26.
//

import Foundation
import SwiftUI

/// 네비게이션 바의 타이틀과 표시 모드를 설정하는 커스텀 ViewModifier입니다.
///
/// `Navititle` 열거형을 통해 앱 내에서 사용되는 타이틀을 중앙 관리합니다.
struct NavigationModifier: ViewModifier {
    let naviTitle: Navititle
    let displayMode: NavigationBarItem.TitleDisplayMode

    /// 앱 전체에서 사용되는 네비게이션 타이틀 목록 정의
    enum Navititle: String {
        case signUp = "회원가입"
        case noticeAlarmType = "알림 보관"
        case communityDetail = "게시글"
        case placeSearch = "어느 위치를 찾고 있나요?"
        case tag = "태그"
        case challenger = "초대할 챌린저 추가"
        case searchChallenger = "챌린저 검색"
        case registration = "일정 추가"
        case registrationEdit = "일정 수정"
        case myProfile = "프로필"
        case myPage = "마이 페이지"
        case myWrittenPosts = "내가 쓴 글"
        case myCommentedPosts = "댓글 단 글"
        case myScrappedPosts = "스크랩"
        case communityPost = "게시글 생성"
        case voteCreate = "투표 만들기"
        case voteEdit = "투표 수정하기"
        case participant = "초대할 챌린저"
        case adminPannel = "관리자 패널"
        case branchSelection = "지부 선택"
        case schoolSelection = "학교 선택"
        case partSelection = "파트 선택"
        case noticeDetail = "공지사항"
        case noticeReadStatus = "공지 열람 현황"
        case noticeAISummary = "AI 요약"
        case detailSchedule = "일정 상세"
        case studyScheduleRegistration = "스터디 일정 등록"
        case communityPostEdit = "게시글 수정"
    }

    func body(content: Content) -> some View {
        content
            .navigationTitle(naviTitle.rawValue)
            .navigationBarTitleDisplayMode(displayMode)
    }
}

extension View {
    /// 네비게이션 타이틀과 디스플레이 모드를 간편하게 설정하는 메서드입니다.
    ///
    /// - Parameters:
    ///   - naviTitle: 미리 정의된 `Navititle` 열거형 값
    ///   - displayMode: 타이틀 표시 모드 (.inline, .large 등)
    /// - Returns: NavigationModifier가 적용된 View
    func navigation(naviTitle: NavigationModifier.Navititle, displayMode: NavigationBarItem.TitleDisplayMode) -> some View {
        modifier(NavigationModifier(naviTitle: naviTitle, displayMode: displayMode))
    }
}
