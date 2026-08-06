//
//  NoticeAlarmView.swift
//  HomePresentation
//
//  Created by JEONG on 7/30/26.
//

import CoreDesignSystem
import CoreUIComponents
import HomeDomain
import SwiftData
import SwiftUI

/// 알림 보관함 화면 — 로컬에 저장된 알림 내역을 최신순으로 보여준다.
public struct NoticeAlarmView: View {

    // MARK: - Property

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \NoticeHistoryData.createdAt, order: .reverse)
    private var notices: [NoticeHistoryData]

    // MARK: - Constants

    fileprivate enum Constants {
        static let emptyTitle: String = "알림 내역이 없습니다."
        static let emptySystemImage: String = "bell.slash"
        static let emptyDescription: String = "새로운 소식이 도착하면 이곳에 표시됩니다."
        static let deleteAllTitle: String = "전체 삭제"
    }

    // MARK: - Init

    public init() {}

    // MARK: - Body

    public var body: some View {
        Group {
            if notices.isEmpty {
                emptyView
            } else {
                noticeList
            }
        }
        .umcDefaultBackground()
        .navigation(naviTitle: NavigationTitle.Notice.alarmArchive, displayMode: .inline)
        .toolbar {
            if !notices.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(Constants.deleteAllTitle, role: .destructive, action: deleteAllNotices)
                }
            }
        }
    }

    // MARK: - Component

    private var emptyView: some View {
        ContentUnavailableView(
            Constants.emptyTitle,
            systemImage: Constants.emptySystemImage,
            description: Text(Constants.emptyDescription)
        )
    }

    private var noticeList: some View {
        List {
            ForEach(notices) { notice in
                NoticeAlarmCard(notice: notice)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(DefaultConstant.defaultListPadding)
            }
            .onDelete(perform: deleteNotices)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Function

    private func deleteNotices(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(notices[index])
        }
        try? modelContext.save()
    }

    private func deleteAllNotices() {
        for notice in notices {
            modelContext.delete(notice)
        }
        try? modelContext.save()
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        NoticeAlarmPreviewSeedView()
    }
    .modelContainer(for: [NoticeHistoryData.self], inMemory: true)
}

private struct NoticeAlarmPreviewSeedView: View {

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \NoticeHistoryData.createdAt, order: .reverse)
    private var notices: [NoticeHistoryData]

    var body: some View {
        NoticeAlarmView()
            .task {
                guard notices.isEmpty else { return }
                seedDummyNotices(modelContext: modelContext)
            }
    }
}

private func seedDummyNotices(modelContext: ModelContext) {
    let dummyNotices: [NoticeHistoryData] = [
        NoticeHistoryData(
            title: "중앙 해커톤 참여 확정",
            content: "축하합니다! 해커톤 참가가 확정되었습니다.",
            icon: .success,
            createdAt: .now.addingTimeInterval(-60 * 5)
        ),
        NoticeHistoryData(
            title: "정기 세션 불참 경고",
            content: "무단 결석 1회가 누적되었습니다.",
            icon: .warning,
            createdAt: .now.addingTimeInterval(-60 * 30)
        ),
        NoticeHistoryData(
            title: "운영진 면접 결과 안내",
            content: "이번 기수 운영진 면접 결과를 확인해주세요.",
            icon: .info,
            createdAt: .now.addingTimeInterval(-60 * 60 * 2)
        ),
        NoticeHistoryData(
            title: "출석 점검 필요",
            content: "출석률이 기준 미만입니다. 다음 세션 출석이 필요합니다.",
            icon: .error,
            createdAt: .now.addingTimeInterval(-60 * 60 * 24)
        )
    ]

    dummyNotices.forEach { modelContext.insert($0) }
    try? modelContext.save()
}
#endif
