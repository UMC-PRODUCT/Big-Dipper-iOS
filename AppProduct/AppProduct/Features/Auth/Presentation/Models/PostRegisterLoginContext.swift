//
//  PostRegisterLoginContext.swift
//  AppProduct
//
//  Created by euijjang97 on 3/10/26.
//

import Foundation

/// 회원가입 직후 세션 복구에 사용할 소셜 로그인 컨텍스트입니다.
enum PostRegisterLoginContext: Equatable {

    // MARK: - Cases

    /// 카카오 로그인 재시도에 필요한 정보
    case kakao(accessToken: String, email: String)

    /// Apple 로그인 재시도에 필요한 정보
    case apple(
        authorizationCode: String,
        email: String?,
        fullName: String?
    )

    /// Google 로그인 재시도에 필요한 정보
    case google(accessToken: String)
}
