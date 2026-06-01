//
//  MissionCardModel.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/11/26.
//

import Foundation

/// 미션 카드 데이터 모델
///
/// 한 주차의 미션 카드 1장에 노출되는 정보를 보유합니다.
/// 상태 변경(`status`)을 허용하므로 ViewModel 단에서 mutation 가능합니다.
public struct MissionCardModel: Equatable, Identifiable {

    // MARK: - Property

    public let id: UUID
    public let week: Int
    public let platform: String
    public let title: String
    public let missionTitle: String
    public let missionType: MissionType
    public var status: MissionStatus
    public let isExtra: Bool

    // MARK: - Initializer

    public init(
        id: UUID = UUID(),
        week: Int,
        platform: String,
        title: String,
        missionTitle: String,
        missionType: MissionType = .link,
        status: MissionStatus,
        isExtra: Bool = false
    ) {
        self.id = id
        self.week = week
        self.platform = platform
        self.title = title
        self.missionTitle = missionTitle
        self.missionType = missionType
        self.status = status
        self.isExtra = isExtra
    }
}
