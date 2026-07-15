//
//  UpdateMyPageProfileImageUseCaseProtocol.swift
//  MyPageDomain
//
//  Created by euijjang97 on 5/10/26.
//

import Foundation

/// 프로필 이미지 변경 UseCase Protocol
///
/// 마이페이지에서 프로필 이미지변경합니다.
public protocol UpdateMyPageProfileImageUseCaseProtocol {
    func execute(
        imageData: Data,
        fileName: String,
        contentType: String
    ) async throws -> ProfileData
}
