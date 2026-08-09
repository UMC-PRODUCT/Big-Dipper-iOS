//
//  ProfileChallengerRecord+HomeMapping.swift
//  HomeData
//
//  Created by euijjang97 on 7/11/26.
//

import CoreDomain
import Foundation
import HomeDomain
import UMCFoundation

// MARK: - ProfileChallengerRecord → HomeGeneration

extension ProfileChallengerRecord {
    /// 상점(보상) 유형 여부 판정에 사용하는 허용 목록.
    ///
    /// `ChallengerPointType.isReward`는 레거시 호환을 위해 `.warning`/`.out`도 양수 배점으로
    /// 유지되어 있어(``ChallengerPointType`` 참고) 그대로 재사용할 수 없다. 대신 실제 상점으로
    /// 취급하는 유형만 명시적으로 나열한다.
    private static let rewardPointTypes: Set<String> = [
        ChallengerPointType.bestWorkbook.rawValue,
        ChallengerPointType.bestWorkbookV2.rawValue,
        ChallengerPointType.blogChallenge.rawValue,
        ChallengerPointType.umcEventReview.rawValue,
        ChallengerPointType.peerReviewSubmission.rawValue,
    ]

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM.dd"
        formatter.timeZone = ServerDateTimeConverter.kstTimeZone
        formatter.locale = Locale(identifier: "ko_KR_POSIX")
        return formatter
    }()

    /// 기수별 상벌점 현황(``HomeGeneration``)으로 변환한다.
    func toHomeGeneration() -> HomeGeneration {
        let sortedPoints = challengerPoints.sorted { lhs, rhs in
            let lhsDate = ServerDateTimeConverter.parseUTCDateTime(lhs.createdAt) ?? .distantPast
            let rhsDate = ServerDateTimeConverter.parseUTCDateTime(rhs.createdAt) ?? .distantPast
            return lhsDate > rhsDate
        }

        var rewardTotal: Double = 0
        var penaltyTotal: Double = 0

        let pointLogs = sortedPoints.map { point -> PointLog in
            let isReward = Self.rewardPointTypes.contains(point.pointType)

            if isReward {
                rewardTotal += abs(point.point)
            } else {
                penaltyTotal += abs(point.point)
            }

            return PointLog(
                id: point.id,
                reason: point.description,
                date: Self.displayDateString(from: point.createdAt),
                point: point.point,
                isReward: isReward
            )
        }

        return HomeGeneration(
            gisuId: gisuId,
            gen: gisu,
            penaltyPoint: penaltyTotal,
            rewardPoint: rewardTotal,
            pointLogs: pointLogs
        )
    }

    private static func displayDateString(from rawValue: String) -> String {
        guard let date = ServerDateTimeConverter.parseUTCDateTime(rawValue) else { return "" }
        return displayDateFormatter.string(from: date)
    }
}

// MARK: - Profile → Home 시즌 카드 소스

extension Profile {
    /// 챌린저 기록(challengerRecords)에서 기수별 상벌점 현황을 구성한다.
    func toHomeGenerations() -> [HomeGeneration] {
        challengerRecords.map { $0.toHomeGeneration() }
    }

    /// 활동일 계산을 위해 기수 시작일을 조회해야 하는 대상 기수 ID 목록.
    ///
    /// 역할(roles)과 챌린저 기록(challengerRecords) 양쪽에서 기수 ID(`gisuId`)를 모아
    /// 합집합을 구성한다.
    func targetGisuIds() -> [String] {
        let recordGisuIds = challengerRecords.map(\.gisuId)
        let roleGisuIds = roles.map(\.gisuId)
        return Array(Set(recordGisuIds + roleGisuIds).filter { !$0.isEmpty && $0 != "0" })
    }
}
