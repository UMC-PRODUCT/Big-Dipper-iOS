//
//  CurriculumDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 2/18/26.
//

import Foundation

/// 파트별 커리큘럼 조회 응답 DTO
///
/// `GET /api/v2/curriculums/overview?gisuId={ID}&part={PART}&weekNo={N}`
struct CurriculumDTO: Codable, Sendable, Equatable {
    let curriculumId: Int
    let title: String
    let weeks: [WeeklyCurriculumDTO]
}

struct WeeklyCurriculumDTO: Codable, Sendable, Equatable {
    let weeklyCurriculumId: Int
    let weekNo: Int
    let title: String
    let startsAt: String
    let endsAt: String
    let isExtra: Bool
}

// MARK: - toDomain

extension CurriculumDTO {
    func toDomain(part: String, now: Date = .now) -> CurriculumData {
        let partType = UMCPartType(apiValue: part)
        let partName = "\(partType?.name ?? part) PART CURRICULUM"

        let missions = weeks
            .map { $0.toDomain(platform: part, now: now) }
            .sorted { $0.week < $1.week }

        let completedCount = weeks.filter { week in
            guard let endDate = week.parsedEndsAt else { return false }
            return now > endDate
        }.count
        let totalCount = weeks.count

        let currentWeekTitle: String = {
            let inProgress = weeks.first { week in
                guard let start = week.parsedStartsAt,
                      let end = week.parsedEndsAt else { return false }
                return start <= now && now <= end
            }
            return inProgress?.title ?? title
        }()

        let progressModel = CurriculumProgressModel(
            partType: partType,
            partName: partName,
            curriculumTitle: currentWeekTitle,
            completedCount: completedCount,
            totalCount: totalCount
        )

        return CurriculumData(progress: progressModel, missions: missions)
    }
}

private extension WeeklyCurriculumDTO {
    func toDomain(platform: String, now: Date) -> MissionCardModel {
        MissionCardModel(
            week: weekNo,
            platform: platform,
            title: title,
            missionTitle: title,
            missionType: .link,
            status: missionStatus(now: now),
            isExtra: isExtra
        )
    }

    func missionStatus(now: Date) -> MissionStatus {
        guard let start = parsedStartsAt, let end = parsedEndsAt else {
            return .notStarted
        }
        if now < start {
            return .notStarted
        } else if now <= end {
            return .inProgress
        } else {
            return .completed
        }
    }

    var parsedStartsAt: Date? {
        startsAt.asISO8601Date
    }

    var parsedEndsAt: Date? {
        endsAt.asISO8601Date
    }
}

// MARK: - Date Parsing

private extension String {
    var asISO8601Date: Date? {
        ISO8601DateFormatter.withFractionalSeconds.date(from: self)
            ?? ISO8601DateFormatter.standard.date(from: self)
    }
}

private extension ISO8601DateFormatter {
    static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
