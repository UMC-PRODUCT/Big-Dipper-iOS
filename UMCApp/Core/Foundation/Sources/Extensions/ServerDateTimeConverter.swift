//
//  ServerDateTimeConverter.swift
//  UMCFoundation
//
//  Created by jaewon Lee on 5/7/26.
//

import Foundation

/// 서버 응답의 UTC 기반 날짜/시간 문자열을 `Date`로 변환하거나 KST 표시 문자열로 포매팅하는 유틸리티.
///
/// - Note: 모든 정적 함수는 `nonisolated`이므로 액터 컨텍스트와 무관하게 호출 가능.
public enum ServerDateTimeConverter {

    // MARK: - TimeZone

    public nonisolated static let utcTimeZone: TimeZone = .init(secondsFromGMT: 0) ?? .current
    public nonisolated static let kstTimeZone: TimeZone =
        .init(identifier: "Asia/Seoul") ?? .current

    // MARK: - Cached Formatter

    /// 파싱/포매팅마다 포매터를 새로 만들면 비용이 크므로 hot-path 포매터는 한 번만 생성해 재사용합니다.
    /// `ISO8601DateFormatter`/`DateFormatter`는 읽기(파싱·포매팅) 시 thread-safe하므로 공유해도 안전합니다.
    private nonisolated static let iso8601WithFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private nonisolated static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private nonisolated static let kstDateFormatter: Foundation.DateFormatter = {
        let formatter = Foundation.DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = kstTimeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private nonisolated static let kstTimeFormatter: Foundation.DateFormatter = {
        let formatter = Foundation.DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = kstTimeZone
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    // MARK: - Function

    public nonisolated static func parseUTCDateTime(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }

        if let date = iso8601WithFraction.date(from: value) {
            return date
        }

        if let date = iso8601.date(from: value) {
            return date
        }

        for format in [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss"
        ] {
            let fallback = DateFormatter()
            fallback.locale = Locale(identifier: "en_US_POSIX")
            fallback.timeZone = utcTimeZone
            fallback.dateFormat = format
            if let date = fallback.date(from: value) {
                return date
            }
        }

        return nil
    }

    public nonisolated static func toUTCDateTimeString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = utcTimeZone
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        return formatter.string(from: date)
    }

    public nonisolated static func parseUTCDateTimeOrTime(
        _ value: String,
        utcDate: String? = nil
    ) -> Date? {
        if let date = parseUTCDateTime(value) {
            return date
        }
        return parseUTCTime(value, utcDate: utcDate)
    }

    public nonisolated static func parseUTCTime(
        _ value: String,
        utcDate: String? = nil
    ) -> Date? {
        guard !value.isEmpty else { return nil }

        let calendar = makeUTCCalendar()
        let baseDate = parseUTCDate(utcDate ?? "") ?? Date()

        for format in ["HH:mm:ss", "HH:mm"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = utcTimeZone
            formatter.dateFormat = format

            guard let time = formatter.date(from: value) else {
                continue
            }

            var components = calendar.dateComponents(
                [.year, .month, .day],
                from: baseDate
            )
            let timeComponents = calendar.dateComponents(
                [.hour, .minute, .second],
                from: time
            )
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute
            components.second = timeComponents.second

            if let date = calendar.date(from: components) {
                return date
            }
        }

        return nil
    }

    public nonisolated static func parseUTCDate(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }

        for format in ["yyyy-MM-dd", "yyyy.MM.dd"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = utcTimeZone
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    public nonisolated static func toKSTDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR_POSIX")
        formatter.timeZone = kstTimeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    public nonisolated static func toKSTTimeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR_POSIX")
        formatter.timeZone = kstTimeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - Private

    nonisolated private static func makeUTCCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utcTimeZone
        return calendar
    }
}
