//
//  MemberProfileRouter.swift
//  CoreNetwork
//
//  Created by euijjang97 on 7/10/26.
//

import Foundation
import Moya

/// 내 프로필 조회 API 라우터.
///
/// Auth `AuthRouter.getMe`/Home `HomeRouter.getGen`/MyPage `MyPageRouter.getMyProfile`이
/// 전부 같은 경로(`GET /api/v1/member/me`)를 호출하던 것을 하나로 합류한다.
public enum MemberProfileRouter: BaseTargetType {
    case getMyProfile

    public var path: String { "/api/v1/member/me" }
    public var method: Moya.Method { .get }
    public var task: Task { .requestPlain }
}
