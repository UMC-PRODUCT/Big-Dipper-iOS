//
//  NavigationTitle.swift
//  CoreUIComponents
//
//  Created by 이예지 on 6/1/26.
//

import Foundation

// MARK: - Protocol

/// 네비게이션 타이틀로 사용할 수 있는 타입이 채택하는 프로토콜입니다.
///
/// `String` raw enum이 채택하면 `rawValue`를 자동으로 획득하므로 선언만으로 충족됩니다.
public protocol NavigationTitleRepresentable {
    var rawValue: String { get }
}

// MARK: - Namespace

/// 앱 전체 네비게이션 타이틀을 피처 단위로 그룹화한 네임스페이스입니다.
///
/// 각 피처가 모듈로 이식될 때 해당 중첩 enum을 그대로 들어내기 쉽도록
/// 그룹명을 피처 모듈명과 일치시킵니다.
public enum NavigationTitle {

    /// 인증/온보딩 화면용 타이틀
    public enum Auth: String, NavigationTitleRepresentable {
        case signUp = "회원가입"
        case resetPassword = "비밀번호 재설정"
    }

    /// 공지사항 화면용 타이틀
    public enum Notice: String, NavigationTitleRepresentable {
        case detail = "공지사항"
        case readStatus = "공지 열람 현황"
        case alarmArchive = "알림 보관"
        case noticeAISummary = "AI 요약"
    }

    /// 커뮤니티 화면용 타이틀
    public enum Community: String, NavigationTitleRepresentable {
        case postDetail = "게시글"
        case createPost = "게시글 생성"
        case editPost = "게시글 수정"
        case tag = "태그"
        case createVote = "투표 만들기"
        case editVote = "투표 수정하기"
    }

    /// 스터디/활동 화면용 타이틀
    public enum Activity: String, NavigationTitleRepresentable {
        case challenger = "초대할 챌린저 추가"
        case searchChallenger = "챌린저 검색"
        case participant = "초대할 챌린저"
        case addSchedule = "일정 추가"
        case editSchedule = "일정 수정"
        case scheduleDetail = "일정 상세"
        case studyScheduleRegistration = "스터디 일정 등록"
    }

    /// 마이페이지 화면용 타이틀
    public enum MyPage: String, NavigationTitleRepresentable {
        case root = "마이 페이지"
        case profile = "프로필"
        case writtenPosts = "내가 쓴 글"
        case commentedPosts = "댓글 단 글"
        case scrappedPosts = "스크랩"
        case productTeam = "UMC PRODUCT"
    }

    /// 운영/관리자 화면용 타이틀
    public enum Maintenance: String, NavigationTitleRepresentable {
        case adminPanel = "관리자 패널"
    }

    /// 여러 피처에서 공통으로 쓰이는 선택 화면용 타이틀
    public enum Shared: String, NavigationTitleRepresentable {
        case branch = "지부 선택"
        case school = "학교 선택"
        case part = "파트 선택"
        case placeSearch = "어느 위치를 찾고 있나요?"
    }
}
