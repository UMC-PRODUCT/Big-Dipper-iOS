//
//  OAuthLoginResult.swift
//  AuthDomain
//
//  Created by euijjang97 on 7/9/26.
//

/// OAuth 소셜 로그인 결과.
///
/// 서버 응답에 따라 기존 회원/신규 회원을 구분한다.
/// - 기존 회원: 로그인 성공. 토큰 저장은 Repository(Data 레이어)가 내부적으로 처리하므로,
///   Domain은 `TokenPair`(Core 인프라 타입)를 알 필요가 없다.
/// - 신규 회원: 회원가입 검증 토큰을 받는다. 회원가입 플로우는 이번 슬라이스 범위 밖(`#944`)이라
///   상위 레이어(ViewModel)는 안전하게 안내만 하고 화면 전환은 수행하지 않는다.
public enum OAuthLoginResult: Equatable, Sendable {
    /// 기존 회원 - 로그인 성공(토큰 저장 완료)
    case existingMember

    /// 신규 회원 - 회원가입 필요
    case newMember(verificationToken: String)
}
