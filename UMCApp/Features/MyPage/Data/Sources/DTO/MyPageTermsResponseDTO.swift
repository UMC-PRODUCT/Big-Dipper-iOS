//
//  MyPageTermsResponseDTO.swift
//  MyPageData
//
//  Created by One on 5/6/26.
//

import Foundation
import MyPageDomain


public struct MyPageTermsResponseDTO: Codable {
    let id: String
    let link: String
    let isMandatory: Bool
    
    private enum CodingKeys: String, CodingKey {
        case id
        case link
        case isMandatory
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try? container.decode(String.self, forKey: .id) {
            self.id = value
        } else if let value = try? container.decode(Int.self, forKey: .id) {
            self.id = String(value)
        } else {
            self.id = ""
        }
        self.link = try container.decode(String.self, forKey: .link)
        self.isMandatory = try container.decode(Bool.self, forKey: .isMandatory)
    }

    public func toDomain() -> MyPageTerms {
        MyPageTerms(
            id: id,
            link: link,
            isMandatory: isMandatory
        )
    }
}
