//
//  BLEAdvertisementPayload+Card.swift
//  CoreNearbyExchange
//
//  Created by One on 8/16/26.
//

import Foundation

public extension BLEAdvertisementPayload {

    /// `ExchangePayload`에서 BLE 축약 광고를 파생한다 (BLE/NFC/UWB transport 공용).
    ///
    /// cardID가 UUID 문자열이면 그 바이트 앞 8B, 아니면 UTF-8 앞 8B(부족분 0 패딩)를 쓴다.
    init(card: ExchangePayload) {
        let prefix: Data
        if let uuid = UUID(uuidString: card.cardID) {
            prefix = withUnsafeBytes(of: uuid.uuid) { Data($0.prefix(8)) }
        } else {
            var bytes = Data(card.cardID.utf8.prefix(8))
            bytes.append(contentsOf: [UInt8](repeating: 0, count: max(0, 8 - bytes.count)))
            prefix = bytes
        }
        self.init(
            cardUUIDPrefix: prefix,
            version: UInt8(clamping: card.version),
            flags: 0
        )
    }
}
