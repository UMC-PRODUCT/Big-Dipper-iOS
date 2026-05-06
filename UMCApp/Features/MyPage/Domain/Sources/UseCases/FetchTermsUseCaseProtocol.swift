//
//  FetchTermsUseCaseProtocol.swift
//  MyPageData
//
//  Created by One on 5/6/26.
//

import Foundation

public protocol FetchTermsUseCaseProtocol {
    func execute(termsType: String) async throws -> MyPageTerms
}
