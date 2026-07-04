//
//  MyPageSectionType.swift
//  MyPage
//
//  Created by 김동민 on 7/4/26.
//

import Foundation

/// MyPage에 표시되는 섹션 타입을 정의하는 열거형
///
/// 외부 링크, 활동 내역, 설정, 소셜 연동 등 MyPage에서 제공하는 모든 섹션 카테고리를 나타냅니다.
public enum MyPageSectionType: String, CaseIterable {
    /// 외부 소셜 링크(GitHub, LinkedIn, Blog)
    case profileLink = "외부링크"
    /// 내가 쓴 글, 댓글 단 글, 스크랩 등 활동 내역
    case myActiveLogs = "내 활동"
    /// 알림 서정, 위치 설정 등
    case settings = "설정"
    /// 개인정보처리 방침, 이용약관 등
    case laws = "법률"
    /// 앱 버전 등 앱 정보
    case info = "정보"
    /// Apple, Kakao 등 소셜 계정 연동 상태
    case socailConnect = "소셜게정 연동"
    /// 회원 정보 처리
    case auth = "회원 관리"
}
