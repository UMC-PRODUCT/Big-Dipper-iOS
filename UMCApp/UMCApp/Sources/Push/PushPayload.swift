//
//  PushPayload.swift
//  UMCApp
//

import Foundation

import ActivityDomain

/// 수신한 푸시의 `userInfo` 에서 앱이 분기에 쓰는 값만 뽑아낸 것.
///
/// `userInfo` 는 `[AnyHashable: Any]` 라 Decodable 경로가 아예 없어 Codable 로 만들지 않는다
/// (Response DTO 규약의 적용 대상이 아니다). FCM 은 `data` 맵을 전부 String 으로 직렬화해
/// APNs `userInfo` 최상위에 평평하게 깔아 주므로, 정수인 `scheduleId` 도 String 그대로 나른다
/// (절대 규칙 #2).
struct PushPayload: Equatable {

    // MARK: - Kind

    /// 앱이 분기 처리하는 푸시 종류. 목록에 없는 값은 `nil` — 배너만 뜨고 분기는 하지 않는다.
    enum Kind: String {
        case attendanceStatusChanged = "ATTENDANCE_STATUS_CHANGED"
    }

    // MARK: - Constants

    private enum Keys {
        static let type = "type"
        static let scheduleId = "scheduleId"
        static let deepLink = "deepLink"
    }

    // MARK: - Property

    let kind: Kind?
    let scheduleId: String?
    let deepLink: URL?

    // MARK: - Init

    init(userInfo: [AnyHashable: Any]) {
        kind = (userInfo[Keys.type] as? String).flatMap(Kind.init(rawValue:))
        // 딥링크는 종류와 무관하게 읽는다 — 탭 라우팅은 `DeepLinkStore` 가 링크 문법으로
        // 판단하므로 여기서 종류를 알 필요가 없다.
        deepLink = (userInfo[Keys.deepLink] as? String).flatMap(URL.init(string:))
        // `scheduleId` 가 정본이고, 빠졌을 때만 딥링크에서 되짚는다 (서버 명세의 폴백 규칙).
        scheduleId = (userInfo[Keys.scheduleId] as? String)
            ?? deepLink.flatMap(AttendanceLink.parse)?.scheduleId
    }

    // MARK: - Computed Property

    /// 출석 상태 변경 푸시일 때만 갱신 대상 일정 식별자를 돌려준다.
    var attendanceScheduleId: String? {
        guard kind == .attendanceStatusChanged else { return nil }
        return scheduleId
    }
}
