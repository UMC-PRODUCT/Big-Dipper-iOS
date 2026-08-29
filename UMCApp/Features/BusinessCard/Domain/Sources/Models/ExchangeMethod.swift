//
//  ExchangeMethod.swift
//  BusinessCardDomain
//
//  Created by One on 8/28/26.
//

import Foundation

/// 명함을 **어떤 경로로** 받았는지 (#1227).
///
/// ``ReceivedCard/exchangeContext`` 와 역할을 나눈다 — 방식은 앱이 아는 값이라 자동으로
/// 기록하고, 「어디서·무슨 자리에서」는 앱이 알 수 없어 사용자가 상세 화면에서 적는다.
/// 둘을 한 문자열에 뭉치면 사용자가 메모를 고치는 순간 경로 정보가 지워진다.
public enum ExchangeMethod: String, Codable, CaseIterable, Sendable {

    /// 근거리 교환 (MP-F06).
    case nearby

    /// QR·공유 링크 수신 (MP-F04 · #1224 인앱 스캔).
    case qrLink

    /// 방식을 기록하기 전에 저장된 명함. 없는 값을 지어내지 않는다.
    case unknown

    // MARK: - Computed Property

    public var displayName: String {
        switch self {
        case .nearby: "근거리 교환"
        case .qrLink: "QR 링크"
        case .unknown: "알 수 없음"
        }
    }

    public var iconName: String {
        switch self {
        case .nearby: "shareplay"
        case .qrLink: "qrcode"
        case .unknown: "questionmark.circle"
        }
    }

    // MARK: - Init

    /// 저장된 원문에서 복원한다. 빈 값·모르는 값은 ``unknown``.
    public init(storedValue: String?) {
        self = storedValue.flatMap(ExchangeMethod.init(rawValue:)) ?? .unknown
    }
}
