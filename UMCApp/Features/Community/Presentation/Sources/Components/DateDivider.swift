//
//  DateDivider.swift
//  CommunityPresentation
//

import SwiftUI
import CoreDesignSystem

/// 메시지 사이 날짜 구분선.
struct DateDivider: View {

    // MARK: - Property

    let date: Date

    // MARK: - Body

    var body: some View {
        Text(Self.formatter.string(from: date))
            .appFont(.caption2, color: .grey600)
            .padding(.horizontal, DefaultSpacing.spacing12)
            .padding(.vertical, DefaultSpacing.spacing4)
            .background(Color.grey100, in: .capsule)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DefaultSpacing.spacing8)
    }

    // MARK: - Formatter

    /// 매 행마다 만들면 스크롤이 버벅인다. 하나만 만들어 재사용한다.
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일 EEEE"
        return formatter
    }()
}
