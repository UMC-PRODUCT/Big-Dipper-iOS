//
//  AddChallengerRecordRequestDTO.swift
//  MyPageData
//

import Foundation

/// 기존 챌린저 기록 추가 요청 DTO
public struct AddChallengerRecordRequestDTO: Encodable {
    public let code: String

    public init(code: String) {
        self.code = code
    }
}
