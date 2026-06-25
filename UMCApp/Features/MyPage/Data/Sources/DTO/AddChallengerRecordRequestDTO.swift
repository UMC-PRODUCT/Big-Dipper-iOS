//
//  AddChallengerRecordRequestDTO.swift
//  MyPageData
//

import Foundation

/// 기존 챌린저 기록 추가 요청 DTO
///
/// `POST /api/v1/challenger-record/member` 요청 바디로 사용됩니다.
/// 운영진이 발급한 코드(`code`)로 챌린저 기록을 본인 계정에 귀속시킵니다.
public struct AddChallengerRecordRequestDTO: Encodable {
    public let code: String

    public init(code: String) {
        self.code = code
    }
}
