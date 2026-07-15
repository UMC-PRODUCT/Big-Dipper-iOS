//
//  AppFlowState.swift
//  UMCApp
//
//  Created by euijjang97 on 7/8/26.
//

import UMCFoundation

/// 앱 전체 화면 상태.
///
/// 앱 진입~홈 진입 수직 슬라이스의 최소 상태에 회원가입(`#944`)·승인 대기(`#945`) 상태를 더한다.
enum AppFlowState: Equatable {
    /// 부트스트랩 화면 (토큰/프로필 확인 후 로그인·메인 여부 판단)
    case bootstrap
    /// 로그인 화면
    case login
    /// 회원가입 화면 (신규 회원 소셜 로그인 시 진입)
    case signUp(
        verificationToken: String,
        email: String?,
        fullName: String?,
        postRegisterLoginContext: PostRegisterLoginContext?
    )
    /// 승인 대기 화면 (미승인 회원 — 기존 챌린저 인증, 로그아웃, 회원 탈퇴만 허용)
    case pendingApproval
    /// 메인 화면 (탭 셸)
    case main
}
