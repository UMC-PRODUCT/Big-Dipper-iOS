#if DEBUG
import CoreWatchDesignSystem
import SwiftUI

// MARK: - WatchFallbackDebugMenu

/// 폴백 9종을 실기기에서 눈으로 확인하기 위한 DEBUG 전용 하네스.
///
/// 실제 진입 신호(위치 권한·GPS 타임아웃·출석 API 응답·공지 수신)는 그 흐름을 만드는
/// #1207·#1210 이 붙인다. 그때까지 이 화면이 없으면 P0-3 외 8종은 개발자가 코드를 고쳐
/// 직접 push 해야만 볼 수 있어 디자인·QA 검수가 불가능하다.
/// 릴리스 빌드에는 포함되지 않는다(절대 규칙 #5).
struct WatchFallbackDebugMenu: View {

    // MARK: - Property

    @Environment(WatchMandatoryNoticeCenter.self) private var noticeCenter

    // MARK: - Body

    var body: some View {
        List {
            Section("전체화면") {
                ForEach(WatchFallbackReason.allCases, id: \.self) { reason in
                    NavigationLink {
                        WatchFallbackView(reason: reason)
                    } label: {
                        row(symbolName: reason.presentation.symbolName,
                            tint: reason.presentation.status.tint,
                            title: reason.presentation.title)
                    }
                    .watchListRowBackground()
                }
            }

            Section("인라인 카드 · 배너") {
                NavigationLink {
                    offlineQueueGallery
                } label: {
                    row(symbolName: "arrow.up.circle.fill",
                        tint: WatchStatus.pending.tint,
                        title: "오프라인 큐 대기 · 만료")
                }
                .watchListRowBackground()

                Button {
                    noticeCenter.present(
                        WatchMandatoryNotice(id: "debug", title: "8월 정기 모임 필수 공지")
                    )
                } label: {
                    row(symbolName: "exclamationmark.bubble.fill",
                        tint: WatchStatus.warning.tint,
                        title: "필수 확인 배너 띄우기")
                }
                .watchListRowBackground()
            }
        }
        .navigationTitle("폴백 하네스")
        .watchScreenBackground()
    }

    // MARK: - Function

    private func row(symbolName: String, tint: Color, title: String) -> some View {
        HStack(spacing: WatchLayout.tightSpacing) {
            Image(systemName: symbolName)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(title)
                .font(.watch(.cardValue))
                .foregroundStyle(WatchColor.textPrimary)
        }
    }

    /// 대기/만료 두 상태를 한 화면에 세워 문구·표면 전환을 바로 비교한다.
    private var offlineQueueGallery: some View {
        ScrollView {
            VStack(spacing: WatchLayout.stackSpacing) {
                WatchOfflineQueueCard(measuredAt: .now.addingTimeInterval(-60 * 90), now: .now)
                WatchOfflineQueueCard(measuredAt: .now.addingTimeInterval(-60 * 200), now: .now)
            }
            .padding(.horizontal, WatchLayout.screenHorizontalPadding)
        }
        .navigationTitle("오프라인 큐")
        .watchScreenBackground()
    }
}

#Preview("WatchFallbackDebugMenu") {
    NavigationStack {
        WatchFallbackDebugMenu()
    }
    .environment(WatchRouter())
    .environment(WatchMandatoryNoticeCenter())
}
#endif
