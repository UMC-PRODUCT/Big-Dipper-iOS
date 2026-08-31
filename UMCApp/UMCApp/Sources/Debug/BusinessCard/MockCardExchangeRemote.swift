//
//  MockCardExchangeRemote.swift
//  UMCApp
//
//  Created by euijjang97 on 8/30/26.
//

#if DEBUG
import Foundation
import UMCFoundation
import BusinessCardData

/// 서버 명함 API 대체 응답 (절대 규칙 #5 — 릴리스 빌드 미포함).
///
/// 실제 서버가 없어서 재조정 규칙을 눈으로 확인할 방법이 이것뿐이다. 시나리오는
/// UserDefaults에 두어 검증 화면이 앱 재시작 없이 갈아 끼운다.
final class MockCardExchangeRemote: ReceivedCardRemoteSyncing, @unchecked Sendable {

    // MARK: - Scenario

    enum Scenario: String, CaseIterable, Identifiable {

        /// 2페이지 정상 응답.
        case twoPages
        /// 마지막 사람이 서버에서 사라진다 — 재조정이 로컬에서도 지워야 한다.
        case itemRemoved
        /// 상대가 나를 지웠다 — `isMutual: false` · `email: null`. 로컬에 남은 이메일이
        /// **지워져야** 한다.
        case mutualRevoked
        /// 2페이지째가 실패한다 — 1페이지 결과도 반영되면 안 된다.
        case secondPageFails
        /// 첫 push가 실패하고 다음 시도에 성공한다 — 미푸시 행이 살아남아야 한다.
        case pushFailsOnce

        var id: String { rawValue }

        var title: String {
            switch self {
            case .twoPages:        return "정상 2페이지"
            case .itemRemoved:     return "서버에서 사라진 항목"
            case .mutualRevoked:   return "상호 해제 (email null)"
            case .secondPageFails: return "2페이지째 실패"
            case .pushFailsOnce:   return "push 1회 실패 후 성공"
            }
        }
    }

    private static let scenarioKey = "debug.card.syncScenario"

    static var scenario: Scenario {
        get {
            UserDefaults.standard.string(forKey: scenarioKey)
                .flatMap(Scenario.init(rawValue:)) ?? .twoPages
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: scenarioKey) }
    }

    // MARK: - Capture

    private(set) var pushedExchanges: [PendingCardExchange] = []
    private(set) var deletedMemberIds: [String] = []
    private var pushAttempts = 0

    // MARK: - ReceivedCardRemoteSyncing

    func fetchExchanges(cursor: String?, size: Int) async throws -> CardExchangePageDTO {
        let scenario = Self.scenario
        guard let cursor else {
            return CardExchangePageDTO(
                content: [makeItem(id: "9001", name: "김서연", scenario: scenario),
                          makeItem(id: "9002", name: "박도윤", scenario: scenario)],
                nextCursor: "9002",
                hasNext: true
            )
        }
        if scenario == .secondPageFails {
            throw MockRemoteError.pageUnavailable
        }
        let lastPage = scenario == .itemRemoved
            ? []
            : [makeItem(id: "9003", name: "이하준", scenario: scenario)]
        _ = cursor
        return CardExchangePageDTO(content: lastPage, nextCursor: nil, hasNext: false)
    }

    func createExchange(_ exchange: PendingCardExchange) async throws {
        pushAttempts += 1
        if Self.scenario == .pushFailsOnce, pushAttempts == 1 {
            throw MockRemoteError.pushRejected
        }
        pushedExchanges.append(exchange)
    }

    func deleteExchange(cardMemberId: String) async throws {
        deletedMemberIds.append(cardMemberId)
    }

    // MARK: - Private Function

    private func makeItem(
        id: String,
        name: String,
        scenario: Scenario
    ) -> CardExchangeItemDTO {
        let isMutual = scenario != .mutualRevoked
        return CardExchangeItemDTO(
            cardMemberId: id,
            name: name,
            nickname: "\(name)닉",
            part: "SPRING",
            generation: "11",
            schoolName: "중앙대학교",
            profileImageURL: nil,
            // 상호가 아니면 서버가 이메일 자체를 내리지 않는다 (6-6).
            email: isMutual ? "\(name)@umc.dev" : nil,
            source: "QR",
            exchangedAt: ServerDateTimeConverter.toUTCDateTimeString(Date()),
            isMutual: isMutual
        )
    }
}

enum MockRemoteError: Error {
    case pageUnavailable
    case pushRejected
}
#endif
