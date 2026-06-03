//
//  ActiveLogs.swift
//  AppProduct
//
//  Created by euijjang97 on 1/31/26.
//

import SwiftUI

/// 활동 이력 목록을 보여주는 섹션
///
/// 사용자의 UMC 활동 내역(스터디, 프로젝트 등)을 리스트 형태로 표시합니다.
/// 각 이력은 ActiveLogRow 컴포넌트를 통해 렌더링됩니다.
struct ActiveLogs: View {

    // MARK: - Property

    /// 활동 이력 데이터 배열
    let rows: [ActivityLog]

    /// 섹션 헤더 타이틀
    let header: String

    /// 활동 이력 추가 버튼 탭 액션
    let onAddTap: (() -> Void)?

    /// 활동 이력 추가 처리 중 여부
    let isAdding: Bool
    /// 활동 이력 추가 성공 직후 여부
    let didRecentlyAdd: Bool

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
            VStack(spacing: DefaultSpacing.spacing16, content: {
                ForEach(rows, id: \.id) { row in
                    ActiveLogRow(row: row)
                        .equatable() // Container-Presenter 패턴으로 렌더링 최적화
                }
            })
        }, header: {
            HStack {
                SectionHeaderView(title: header)
                Spacer()
                if let onAddTap {
                    Button(action: onAddTap) {
                        if isAdding {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label(
                                didRecentlyAdd ? "추가되었습니다" : "기록 추가",
                                systemImage: didRecentlyAdd ? "checkmark.circle.fill" : "plus.circle"
                            )
                                .labelStyle(.titleAndIcon)
                                .labelIconToTitleSpacing(DefaultSpacing.spacing8)
                                .appFont(.footnote, color: didRecentlyAdd ? .green : .indigo500)
                                .contentTransition(.symbolEffect(.replace))
                                .animation(.easeInOut(duration: 0.25), value: didRecentlyAdd)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isAdding)
                }
            }
        })
    }
}

// MARK: - Preview

private let activeLogsPreviewRows: [ActivityLog] = ManagementTeam.allCases.enumerated().map { index, role in
    ActivityLog(
        part: UMCPartType.allCases[index % UMCPartType.allCases.count],
        generation: 12 - index,
        role: role
    )
}

#Preview("활동 이력 - 전체 역할") {
    Form {
        ActiveLogs(
            rows: activeLogsPreviewRows,
            header: "활동 이력"
        )
    }
}

#Preview("활동 이력 - 챌린저(무색)") {
    Form {
        ActiveLogs(
            rows: [
                ActivityLog(
                    part: .front(type: .ios),
                    generation: 11,
                    role: .challenger
                )
            ],
            header: "활동 이력"
        )
    }
}
