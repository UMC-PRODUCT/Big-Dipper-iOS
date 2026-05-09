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
    
    public func toDomain() -> MyPageTerms {
        MyPageTerms(
            id: id,
            link: link,
            isMandatory: isMandatory
        )
    }
}
