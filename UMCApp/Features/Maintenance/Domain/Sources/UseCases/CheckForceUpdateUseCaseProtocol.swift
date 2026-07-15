//
//  CheckForceUpdateUseCaseProtocol.swift
//  MaintenanceDomain
//
//  Created by euijjang97 on 7/10/26.
//

/// 강제 업데이트 필요 여부를 판정하는 UseCase 인터페이스.
public protocol CheckForceUpdateUseCaseProtocol {
    func execute() async -> Bool
}
