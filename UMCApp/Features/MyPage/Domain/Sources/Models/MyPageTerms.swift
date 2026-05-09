//
//  MyPageTerms.swift
//  MyPageData
//
//  Created by One on 5/6/26.
//

import Foundation

/// 마이페이지 약관 링크 정보
public struct MyPageTerms {
    let id: String
    let link: String
    let isMandatory: Bool
    
    public init(id: String, link: String, isMandatory: Bool) {
        self.id = id
        self.link = link
        self.isMandatory = isMandatory
    }
}
