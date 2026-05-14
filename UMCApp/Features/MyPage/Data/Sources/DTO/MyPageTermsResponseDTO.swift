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
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
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
