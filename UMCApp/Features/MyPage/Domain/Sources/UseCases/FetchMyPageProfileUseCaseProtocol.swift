//
//  FetchMyPageProfileUseCaseProtocol.swift
//  MyPageDomain
//
//  Created by euijjang97 on 5/10/26.
//

import Foundation

public protocol FetchMyPageProfileUseCaseProtocol {
    func execute() async throws -> ProfileData
}
