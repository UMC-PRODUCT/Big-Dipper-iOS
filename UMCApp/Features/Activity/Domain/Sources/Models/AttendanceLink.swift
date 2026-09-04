//
//  AttendanceLink.swift
//  ActivityDomain
//

import Foundation

/// 출석 화면을 가리키는 내부 링크 — 생성과 해석을 한 타입에 모은다.
///
/// 출석 승인/반려 푸시가 `data.deepLink` 로 `umc://attendance/{scheduleId}` 를 싣고 오고,
/// 알림을 탭하면 앱이 이 표기를 해석해 해당 일정의 출석 카드로 착지한다. 표기를 App 이 아니라
/// Domain 이 소유하는 이유는 Community 의 `MessageLink`·명함의 `CardLink` 와 같다 — 굽는 쪽과
/// 읽는 쪽이 같은 표를 봐야 "보낸 링크가 열린다" 가 성립한다.
public struct AttendanceLink: Hashable, Sendable {

    // MARK: - Constants

    private enum Constants {
        /// 커스텀 스킴. `Info.plist` 의 `CFBundleURLTypes` 에 등록된 값과 같아야 한다.
        static let scheme = "umc"
        static let host = "attendance"
    }

    // MARK: - Property

    public let scheduleId: String

    // MARK: - Init

    public init(scheduleId: String) {
        self.scheduleId = scheduleId
    }

    // MARK: - Computed Property

    /// 서버·앱이 함께 쓰는 정규 링크 문자열 (`umc://attendance/1234`).
    public var urlString: String {
        "\(Constants.scheme)://\(Constants.host)/\(scheduleId)"
    }

    /// ``urlString`` 을 URL 로 만든 값.
    public var url: URL? {
        URL(string: urlString)
    }

    // MARK: - Static Function

    /// 출석 딥링크 URL 을 해석한다. 출석 링크가 아니면 `nil`.
    public static func parse(_ url: URL) -> AttendanceLink? {
        guard url.scheme?.lowercased() == Constants.scheme,
              url.host?.lowercased() == Constants.host,
              let scheduleId = url.pathComponents.first(where: { $0 != "/" }),
              isValidIdentifier(scheduleId)
        else { return nil }

        return AttendanceLink(scheduleId: scheduleId)
    }

    // MARK: - Private Static Function

    /// 서버 식별자는 정수를 String 으로 직렬화한 값이다(핵심 규칙 #2). 숫자로 좁혀 두면
    /// 같은 host 아래에 다른 표기가 생겨도 일정 링크로 오인해 열지 않는다.
    private static func isValidIdentifier(_ value: String) -> Bool {
        !value.isEmpty && value.allSatisfy(\.isNumber)
    }
}
