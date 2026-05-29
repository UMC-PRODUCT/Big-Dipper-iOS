//
//  DeleteMemberUseCaseProtocol.swift
//  MyPageDomain
//
//  Created by euijjang97 on 5/10/26.
//

import Foundation

/// 챌린저 계정 제거 UseCase Protocol
///
/// 계정 삭제 완료 후 서버 로그아웃과 DI 캐시 초기화를 함께 수행
/// 에러케이스:
///
///     승인대기화면에서 회원 탈퇴
///     feature: "Auth",
///     action: "deleteMemberFromPendingApproval"
///
///     MyPage에서 계정삭제
///     feature: "MyPage",
///     action: "deleteMember"
public protocol DeleteMemberUseCaseProtocol {
    func execute() async throws
}
