//
//  ActiveLogs.swift
//  MyPagePresentation
//
//  Created by euijjang97 on 8/10/26.
//

import CoreDesignSystem
import CoreUIComponents
import MyPageDomain
import SwiftUI

/// 기수별 활동 이력 목록과 운영진 코드로 기록을 추가하는 진입점을 담은 섹션.
struct ActiveLogs: View {

    // MARK: - Property

    private let rows: [ActivityLog]
    private let header: String
    private let onAddTap: (() -> Void)?
    private let isAdding: Bool
    private let didRecentlyAdd: Bool

    private enum Constants {
        static let addTitle = "기록 추가"
        static let addedTitle = "추가되었습니다"
        static let addIcon = "plus.circle"
        static let addedIcon = "checkmark.circle.fill"
        static let feedbackAnimationDuration: Double = 0.25
    }

    // MARK: - Init

    init(
        rows: [ActivityLog],
        header: String,
        onAddTap: (() -> Void)? = nil,
        isAdding: Bool = false,
        didRecentlyAdd: Bool = false
    ) {
        self.rows = rows
        self.header = header
        self.onAddTap = onAddTap
        self.isAdding = isAdding
        self.didRecentlyAdd = didRecentlyAdd
    }

    // MARK: - Body

    var body: some View {
        Section(content: {
            VStack(spacing: DefaultSpacing.spacing16) {
                ForEach(rows) { row in
                    // Container-Presenter 분리로 목록 전체 재계산을 막는다.
                    ActiveLogRow(row: row)
                        .equatable()
                }
            }
        }, header: {
            HStack {
                SectionHeaderView(title: header)
                Spacer()
                addButton
            }
        })
    }

    // MARK: - View Component

    @ViewBuilder
    private var addButton: some View {
        if let onAddTap {
            Button(action: onAddTap) {
                if isAdding {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    addLabel
                }
            }
            .buttonStyle(.plain)
            .disabled(isAdding)
        }
    }

    private var addLabel: some View {
        Label(
            didRecentlyAdd ? Constants.addedTitle : Constants.addTitle,
            systemImage: didRecentlyAdd ? Constants.addedIcon : Constants.addIcon
        )
        .labelStyle(.titleAndIcon)
        .labelIconToTitleSpacing(DefaultSpacing.spacing8)
        .appFont(.footnote, color: didRecentlyAdd ? .green : .indigo500)
        .contentTransition(.symbolEffect(.replace))
        .animation(
            .easeInOut(duration: Constants.feedbackAnimationDuration),
            value: didRecentlyAdd
        )
    }
}
