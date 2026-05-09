//
//  AddChallengerRecordUseCaseProtocol.swift
//  MyPageDomain
//
//  Created by euijjang97 on 5/10/26.
//

import Foundation

/// 챌린저 기록 추가 UseCase Protocol
///
/// 운영진에게 발급받은 코드로 기존 챌린저 기록을 내 프로필에 연결합니다.
public protocol AddChallengerRecordUseCaseProtocol {
    /// 챌린저 기록을 추가합니다.
    ///
    /// - Parameter code: 운영진 발급 6자리 코드
    func execute(code: String) async throws
}
