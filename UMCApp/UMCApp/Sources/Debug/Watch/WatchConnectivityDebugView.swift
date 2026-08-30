//
//  WatchConnectivityDebugView.swift
//  UMCApp
//
//  Created by euijjang97 on 8/30/26.
//

#if DEBUG
import CoreDI
import CoreWatchConnectivity
import SwiftUI
import WatchConnectivity

/// 워치 연동 **배선 확인용** 화면. 제품 화면이 아니다.
struct WatchConnectivityDebugView: View {

    // MARK: - Property

    let container: DIContainer

    @State private var log: [String] = []

    /// `@Observable` 이라 body 에서 프로퍼티를 읽는 것만으로 관측이 걸린다 — 별도 ViewModel 없이
    /// 델리게이트 콜백이 상태를 바꾸면 이 화면이 다시 그려진다.
    private var coordinator: WatchSessionCoordinator {
        container.resolve(WatchSessionCoordinator.self)
    }

    // MARK: - Body

    var body: some View {
        List {
            stateSection
            publishSection
        }
        .navigationTitle("워치 연동")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Section

    private var stateSection: some View {
        Section {
            LabeledContent("isSupported", value: "\(WCSession.isSupported())")
            LabeledContent("isActivated", value: "\(coordinator.isActivated)")
            LabeledContent("isReachable", value: "\(coordinator.isReachable)")
            LabeledContent("receivedState", value: coordinator.receivedState == nil ? "없음" : "있음")
        } header: {
            Text("WCSession 상태")
        } footer: {
            Text("""
            시뮬레이터 페어링(iPhone 17 Pro + Apple Watch)에서 두 앱을 모두 실행한 뒤 확인한다. \
            먼저 이 화면의 isActivated 가 true 가 되어야 한다 — false 로 남으면 앱 진입점의 \
            activateWatchSession() 이 돌지 않았거나 페어링이 잡히지 않은 것이다.
            """)
        }
    }

    private var publishSection: some View {
        Section {
            Button("스냅샷 퍼블리시") { publishSnapshot() }
                .disabled(!coordinator.isActivated)

            ForEach(Array(log.enumerated()), id: \.offset) { _, line in
                Text(line).font(.caption).monospaced()
            }
        } header: {
            Text("iPhone → Watch")
        } footer: {
            Text("""
            퍼블리시하면 워치 화면의 「스냅샷」 줄이 「스냅샷 없음」에서 수신 시각으로 바뀌어야 \
            한다(iPhone → Watch 방향 성립). 반대 방향은 워치에서 「동기화 요청」을 눌러 확인한다 \
            — 로그인 상태면 .state 가, 로그아웃 상태면 notSignedIn 실패가 돌아와야 한다.
            """)
        }
    }

    // MARK: - Function

    private func publishSnapshot() {
        let state = WatchSessionState(
            isSignedIn: true,
            schedules: [],
            notices: [],
            generatedAt: Date()
        )
        do {
            try coordinator.publishSessionState(state)
            log.append("퍼블리시 성공 · \(state.generatedAt.formatted(date: .omitted, time: .standard))")
        } catch {
            log.append("퍼블리시 실패 · \(error)")
        }
    }
}
#endif
