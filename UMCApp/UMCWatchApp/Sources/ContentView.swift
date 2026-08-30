//
//  ContentView.swift
//  UMCWatchApp
//
//  Created by euijjang97 on 4/24/26.
//

import CoreWatchConnectivity
import SwiftUI

/// **배선 확인용 최소 화면.** 제품 화면(출석·공지)은 별도 이슈다.
///
/// 여기서 보는 것은 세 가지뿐이다 — 세션이 활성화되는지, iPhone 이 퍼블리시한 스냅샷이
/// 도착하는지, 워치가 보낸 `syncRequest` 에 응답이 돌아오는지.
///
/// 디자인 토큰을 쓰지 않는다: `CoreDesignSystem` 은 워치 타겟에 링크되어 있지 않고,
/// 검증 화면에 토큰을 들이려고 모듈 의존성을 늘릴 이유가 없다.
struct ContentView: View {

    // MARK: - Property

    let coordinator: WatchSessionCoordinator

    @State private var lastResult: String = "—"

    // MARK: - Body

    var body: some View {
        List {
            Section("세션") {
                LabeledContent("활성화", value: coordinator.isActivated ? "O" : "X")
                LabeledContent("연결", value: coordinator.isReachable ? "O" : "X")
            }

            Section("스냅샷") {
                Text(snapshotSummary)
            }

            Section("동기화") {
                Button("동기화 요청") {
                    Task { await requestSync() }
                }
                .disabled(!coordinator.isReachable)

                Text(lastResult)
            }
        }
        .font(.caption)
        .navigationTitle("연결 상태")
    }

    // MARK: - Function

    private var snapshotSummary: String {
        guard let state = coordinator.receivedState else { return "스냅샷 없음" }
        let generatedAt = state.generatedAt.formatted(date: .omitted, time: .standard)
        return "\(generatedAt) 수신 · 일정 \(state.schedules.count) · 공지 \(state.notices.count)"
    }

    private func requestSync() async {
        do {
            let state = try await coordinator.requestSync()
            lastResult = """
                로그인 \(state.isSignedIn ? "O" : "X") · \
                일정 \(state.schedules.count) · 공지 \(state.notices.count)
                """
        } catch {
            lastResult = "실패: \(error)"
        }
    }
}
