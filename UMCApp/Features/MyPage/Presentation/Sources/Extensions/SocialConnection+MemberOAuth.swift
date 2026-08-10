//
//  SocialConnection+MemberOAuth.swift
//  MyPagePresentation
//
//  Created by euijjang97 on 8/10/26.
//

import AuthDomain
import MyPageDomain

extension SocialConnection {
    /// 서버 OAuth 연동 정보를 화면 표시용 모델로 변환합니다.
    ///
    /// 앱이 모르는 provider(`OAuthProvider.unknown`)는 화면에서 무시하도록 `nil`을 반환합니다.
    init?(memberOAuth: MemberOAuth) {
        guard let socialType = memberOAuth.provider.socialType else {
            return nil
        }

        self.init(memberOAuthId: memberOAuth.memberOAuthId, socialType: socialType)
    }
}
