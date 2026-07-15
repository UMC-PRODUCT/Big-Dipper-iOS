//
//  DeleteMemberUseCaseProtocol.swift
//  MyPageDomain
//
//  Created by euijjang97 on 5/10/26.
//

import Foundation

/// 회원 탈퇴 UseCase Protocol
///
/// 모든 데이터를 지우고 회원 탈퇴를 진행합니다.
public protocol DeleteMemberUseCaseProtocol {
    func execute() async throws
}
