//
//  UpdateMyPageProfileImageUseCaseProtocol.swift
//  MyPageDomain
//
//  Created by euijjang97 on 5/10/26.
//

import Foundation

public protocol UpdateMyPageProfileImageUseCaseProtocol {
    func execute(
        imageData: Data,
        fileName: String,
        contentType: String
    ) async throws -> ProfileData
}
