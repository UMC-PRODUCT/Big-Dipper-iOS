//
//  NoticeHistoryData.swift
//  HomeDomain
//
//  Created by euijjang97 on 1/20/26.
//

import Foundation
import SwiftData

/// 알림 히스토리 로컬 저장 모델 (SwiftData)
///
/// 사용자의 알림 내역을 로컬 데이터베이스에 저장하고 관리합니다.
/// `NoticeAlarmType`을 포함해 알림의 성격(정보, 경고 등)을 구분합니다.
@Model
public final class NoticeHistoryData {

    // MARK: - Property

    public var id: UUID = UUID()
    public var title: String = ""
    public var content: String = ""
    /// 알림 타입 rawValue 저장값
    public var iconRaw: String = NoticeAlarmType.info.rawValue
    public var createdAt: Date = Date()

    /// 알림 타입. SwiftData 저장은 `iconRaw`(String)로 하고 앱에서는 enum으로 접근합니다.
    public var icon: NoticeAlarmType {
        get { NoticeAlarmType(rawValue: iconRaw) ?? .info }
        set { iconRaw = newValue.rawValue }
    }

    // MARK: - Init

    public init(
        id: UUID = .init(),
        title: String,
        content: String,
        icon: NoticeAlarmType,
        createdAt: Date
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.iconRaw = icon.rawValue
        self.createdAt = createdAt
    }
}
