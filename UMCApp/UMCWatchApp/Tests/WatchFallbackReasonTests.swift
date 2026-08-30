import CoreLocation
import CoreWatchConnectivity
import Foundation
import Testing
@testable import UMCWatchApp

@Suite("WatchFallbackReason — 무음 실패 방지 계약")
struct WatchFallbackReasonTests {

    // MARK: - Test

    @Test("9종 전부 제목·설명이 비어있지 않다")
    func allCasesHaveNonEmptyTitleAndMessage() {
        for reason in WatchFallbackReason.allCases {
            #expect(!reason.presentation.title.isEmpty)
            #expect(!reason.presentation.message.isEmpty)
        }
    }

    @Test("제목이 서로 고유하다 — 같은 문구로 두 화면을 만들지 않는다")
    func titlesAreUnique() {
        let titles = WatchFallbackReason.allCases.map(\.presentation.title)
        #expect(Set(titles).count == titles.count)
    }

    @Test("4축이 전부 최소 1케이스씩 커버된다")
    func everyCategoryIsCovered() {
        let coveredCategories = Set(WatchFallbackReason.allCases.map(\.category))
        #expect(coveredCategories == Set(WatchFailureCategory.allCases))
    }

    @Test("분류할 수 없는 에러는 재시도 가능한 화면(checkInRequestFailed)으로 귀착된다")
    func unknownErrorFallsBackToCheckInRequestFailed() {
        struct UnknownError: Error {}
        let reason = WatchFallbackReason(classifying: UnknownError())

        #expect(reason == .checkInRequestFailed)
    }

    @Test("연결 끊김(notReachable)은 phoneDisconnected 로 분류된다")
    func notReachableMapsToPhoneDisconnected() {
        let reason = WatchFallbackReason(classifying: WatchConnectivityError.notReachable)

        #expect(reason == .phoneDisconnected)
    }

    @Test("세션 미활성(sessionNotActivated)은 phoneDisconnected 로 분류된다")
    func sessionNotActivatedMapsToPhoneDisconnected() {
        let reason = WatchFallbackReason(classifying: WatchConnectivityError.sessionNotActivated)

        #expect(reason == .phoneDisconnected)
    }

    @Test("위치 권한 거부(CLError.denied)는 locationPermissionDenied 로 분류된다")
    func locationDeniedMapsToPermissionDenied() {
        let reason = WatchFallbackReason(classifying: CLError(.denied))

        #expect(reason == .locationPermissionDenied)
    }

    @Test("위치를 찾지 못하면(CLError.locationUnknown) locationUnavailable 로 분류된다")
    func locationUnknownMapsToLocationUnavailable() {
        let reason = WatchFallbackReason(classifying: CLError(.locationUnknown))

        #expect(reason == .locationUnavailable)
    }

    @Test("위치 측위 네트워크 오류(CLError.network)도 locationUnavailable 로 분류된다")
    func locationNetworkErrorMapsToLocationUnavailable() {
        let reason = WatchFallbackReason(classifying: CLError(.network))

        #expect(reason == .locationUnavailable)
    }

    @Test("네트워크 미연결(URLError.notConnectedToInternet)은 offlineQueued 로 분류된다")
    func notConnectedMapsToOfflineQueued() {
        let reason = WatchFallbackReason(classifying: URLError(.notConnectedToInternet))

        #expect(reason == .offlineQueued)
    }

    @Test("분류되지 않은 위치 에러도 서버 실패가 아니라 locationUnavailable 로 간다")
    func unknownLocationErrorStaysInLocationCategory() {
        let reason = WatchFallbackReason(classifying: CLError(.geocodeFoundNoResult))

        #expect(reason == .locationUnavailable)
        #expect(reason.category != .server)
    }

    @Test("활성 CTA 를 가진 케이스는 사용자가 다음에 할 일을 문구로도 알려 준다")
    func actionableCasesExplainTheNextStep() {
        for reason in WatchFallbackReason.allCases {
            let presentation = reason.presentation
            guard presentation.secondaryAction != nil else { continue }
            // 보조 CTA 는 워치 밖(iPhone)으로 넘어가는 선택지라, 넘어가서 무엇을 할지
            // 힌트가 없으면 화면을 닫는 순간 사용자가 길을 잃는다.
            #expect(presentation.hint?.isEmpty == false)
        }
    }

    @Test("비활성 CTA 를 가진 케이스는 반드시 사유(disabledAction.reason)를 함께 가진다")
    func disabledActionsAlwaysCarryAReason() {
        for reason in WatchFallbackReason.allCases {
            guard let disabledAction = reason.presentation.disabledAction else { continue }
            #expect(!disabledAction.reason.isEmpty)
        }
    }
}
