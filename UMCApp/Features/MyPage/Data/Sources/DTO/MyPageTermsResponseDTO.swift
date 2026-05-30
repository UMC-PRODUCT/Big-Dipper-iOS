//
//  MyPageTermsResponseDTO.swift
//  MyPageData
//
//  Created by One on 5/6/26.
//

import Foundation
import MyPageDomain


/// 마이페이지 약관 조회 API 응답 DTO
///
/// 서버가 내려주는 약관 항목 하나를 표현한다. 서버는 모든 정수 값을 String 으로
/// 직렬화하므로 `id` 는 `decodeFlexibleString` 으로 유연하게 디코딩하며,
/// `toDomain()` 을 통해 도메인 모델 ``MyPageTerms`` 로 변환한다.
public struct MyPageTermsResponseDTO: Codable {
    /// 약관 식별자. 서버가 String/Int 어느 형태로 내려도 String 으로 디코딩한다.
    let id: String
    /// 약관 원문(웹 페이지) 링크 URL 문자열
    let link: String
    /// 필수 동의 여부. `true` 면 가입/이용을 위해 반드시 동의해야 하는 약관이다.
    let isMandatory: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case link
        case isMandatory
    }

    /// 서버 응답 JSON 을 디코딩한다.
    ///
    /// `id` 는 정수가 String 으로 직렬화되는 서버 정책에 대응하기 위해
    /// `decodeFlexibleString` 헬퍼로 디코딩한다.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeFlexibleString(forKey: .id)
        self.link = try container.decode(String.self, forKey: .link)
        self.isMandatory = try container.decode(Bool.self, forKey: .isMandatory)
    }
    
    /// DTO 를 JSON 으로 인코딩한다. (테스트 라운드트립 / 캐싱 용도)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(link, forKey: .link)
        try container.encode(isMandatory, forKey: .isMandatory)
    }
    
    /// DTO 를 도메인 모델 ``MyPageTerms`` 로 변환한다.
    public func toDomain() -> MyPageTerms {
        MyPageTerms(
            id: id,
            link: link,
            isMandatory: isMandatory
        )
    }
}
