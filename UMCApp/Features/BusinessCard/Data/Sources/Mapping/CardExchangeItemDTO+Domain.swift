//
//  CardExchangeItemDTO+Domain.swift
//  BusinessCardData
//
//  Created by JEONG on 8/30/26.
//

import Foundation
import UMCFoundation
import BusinessCardDomain

// 명함첩 서버 응답 → 로컬 레코드 매핑.
//
// 날짜는 `ServerDateTimeConverter` 를 재사용한다 — 포매터를 새로 만들면 서버가 밀리초를
// 붙이는 순간 이 경로만 조용히 파싱에 실패한다.

extension CardExchangeItemDTO {

    /// 서버가 준 교환 시각. 못 읽으면 `nil` — 호출부가 로컬 값을 지킬지 정한다.
    var exchangedAtDate: Date? {
        ServerDateTimeConverter.parseUTCDateTime(exchangedAt)
    }

    /// 서버 정본으로 새 명함첩 행을 만든다.
    ///
    /// `cardID` 는 memberId에서 결정적으로 만든다 — 같은 상대가 QR·근거리·서버 어느
    /// 경로로 들어와도 한 장으로 합쳐져야 한다.
    func makeRecord(ownerMemberId: String, syncedAt: Date) -> ReceivedCardRecord {
        ReceivedCardRecord(
            ownerMemberId: ownerMemberId,
            cardID: "member:\(cardMemberId)",
            memberId: cardMemberId,
            name: name,
            nickname: nickname,
            partRaw: part,
            generation: generation,
            university: schoolName,
            email: email,
            github: github,
            linkedIn: linkedIn,
            blog: blog,
            avatarURL: profileImageURL,
            exchangedAt: exchangedAtDate ?? Date(),
            exchangeContext: nil,
            exchangeMethodRaw: ExchangeMethod(serverSource: source).rawValue,
            serverSyncedAt: syncedAt,
            isMutual: isMutual
        )
    }

    /// 기존 행에 서버 값을 덮어쓴다.
    ///
    /// - Important: `email` 은 **무조건** 서버 값으로 간다. `?? record.email` 같은 폴백을
    ///   쓰면 상대가 나를 명함첩에서 지운 뒤에도 이미 받아 둔 이메일이 계속 보인다.
    /// - Important: `exchangeContext`(사용자 메모)는 서버에 없는 로컬 전용 필드다.
    ///   여기서 건드리면 사용자가 적은 메모가 동기화 한 번에 사라진다.
    func applyServerFields(to record: ReceivedCardRecord, syncedAt: Date) {
        if record.cardID.isEmpty {
            record.cardID = "member:\(cardMemberId)"
        }
        record.memberId = cardMemberId
        record.name = name
        record.nickname = nickname
        record.partRaw = part
        record.generation = generation
        record.university = schoolName
        record.email = email
        record.github = github
        record.linkedIn = linkedIn
        record.blog = blog
        record.avatarURL = profileImageURL
        if let exchangedAtDate {
            record.exchangedAt = exchangedAtDate
        }
        // 방식은 로컬이 더 정확할 수 있다 — 근거리 교환은 앱만 아는 사실이고, 서버가
        // 모르는 값을 보내오면 `.unknown` 이 되어 이미 아는 경로를 지운다.
        if ExchangeMethod(storedValue: record.exchangeMethodRaw) == .unknown {
            record.exchangeMethodRaw = ExchangeMethod(serverSource: source).rawValue
        }
        record.isMutual = isMutual
        record.serverSyncedAt = syncedAt
        record.updatedAt = .now
    }
}

extension ExchangeMethod {

    /// 서버 `source` 문자열에서 복원한다. 모르는 값은 ``unknown`` 으로 흡수한다 —
    /// 서버가 값을 늘려도 앱이 깨지지 않는다.
    init(serverSource: String) {
        switch serverSource.uppercased() {
        case "NEARBY": self = .nearby
        case "QR": self = .qrLink
        default: self = .unknown
        }
    }

    /// 서버로 올릴 `source` 값. 서버가 non-null 을 요구하므로 방식 기록 이전(#1227)에
    /// 저장된 행은 `QR` 로 올린다 — 그 시기의 저장 경로가 QR·딥링크였다.
    var serverSourceValue: String {
        switch self {
        case .nearby: "NEARBY"
        case .qrLink, .unknown: "QR"
        }
    }
}
