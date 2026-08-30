import CoreLocation
import CoreWatchConnectivity
import Foundation

// MARK: - WatchFailureCategory

/// 실패 원인의 4축 분류. 화면을 고르는 축이 아니라 **원인을 진단하는 축**이다 —
/// 같은 축이어도 사용자가 할 수 있는 행동이 다르면 화면은 갈라진다.
enum WatchFailureCategory: Hashable, Sendable, CaseIterable {
    /// 권한 — 사용자가 iPhone 설정에서 풀어야 한다.
    case permission
    /// 연결 — 위치 신호·iPhone 링크·네트워크. 시간이 지나면 저절로 풀릴 수 있다.
    case connectivity
    /// 세션 — 출석 세션 자체의 상태(이미 완료·창 마감·필수 확인). 재시도로 바뀌지 않는다.
    case session
    /// 서버 — 요청은 나갔는데 서버가 받지 못했다. 재시도가 유효하다.
    case server
}

// MARK: - WatchFallbackReason

/// 워치가 사용자에게 **반드시 설명해야 하는** 실패 상태.
///
/// 연관값을 두지 않는 이유: `CaseIterable` 합성을 살리기 위해서다. 케이스를 추가하면
/// `allCases` 가 자동으로 늘어나 테스트가 새 케이스를 강제로 검사한다. 시각(HH:MM)·공지 제목
/// 같은 가변 정보는 소비하는 쪽(`WatchOfflineQueueCard`·`WatchMandatoryNoticeBanner`)이
/// `WatchFallbackPresentation.replacing(title:message:hint:)` 로 따로 꽂는다.
/// `WatchRoute.fallback` 연관값이라 `WatchRoute` 와 같은 `public` 이어야 한다
/// (`public enum` 은 연관값 타입도 최소 같은 접근 수준을 요구한다).
public enum WatchFallbackReason: Hashable, Sendable, CaseIterable {
    /// P0-1 위치 권한 거부.
    case locationPermissionDenied
    /// P0-2 위치 확인 실패(GPS 타임아웃 등).
    case locationUnavailable
    /// P0-3 iPhone 연결 끊김.
    case phoneDisconnected
    /// P0-4 출석 요청 실패.
    case checkInRequestFailed
    /// P0-5 이미 출석 처리됨.
    case alreadyCheckedIn
    /// P0-6 출석 인정 시간 마감.
    case checkInWindowClosed
    /// P0-7 전송 대기 중 — 유효 시간 이내.
    case offlineQueued
    /// P0-7 전송 유효 시간 초과.
    case offlineQueueExpired
    /// P0-8 필수 확인 공지 미확인.
    case mandatoryNoticeUnread

    /// 4축 중 어디에 속하는지. `default:` 를 두지 않는다 — 케이스가 늘면 컴파일 에러로 드러나야
    /// 새 실패 원인이 분류 없이 조용히 묻히지 않는다.
    var category: WatchFailureCategory {
        switch self {
        case .locationPermissionDenied:
            return .permission

        case .locationUnavailable, .phoneDisconnected, .offlineQueued, .offlineQueueExpired:
            // GPS·iPhone 링크·네트워크는 기기 바깥 신호 실패라 권한/세션/서버 어디에도 속하지
            // 않는다. 시간이 지나거나 환경이 바뀌면 저절로 풀릴 수 있다는 공통점으로 묶는다.
            return .connectivity

        case .alreadyCheckedIn, .checkInWindowClosed, .mandatoryNoticeUnread:
            return .session

        case .checkInRequestFailed:
            return .server
        }
    }
}

// MARK: - WatchFallbackReason + Classifying

extension WatchFallbackReason {

    /// 어떤 에러도 화면 없이 사라지지 않게 한다 — 반환값이 Optional 이 아닌 것이 이 API 의 계약이다.
    /// 분류할 수 없는 에러는 `.checkInRequestFailed` 로 보낸다: 재시도와 iPhone 대체 경로를
    /// 모두 가진 유일한 복구 가능 화면이라, 원인을 몰라도 사용자가 막히지 않는다.
    init(classifying error: Error) {
        switch error {
        case let connectivityError as WatchConnectivityError:
            switch connectivityError {
            case .notSupported, .notReachable, .sessionNotActivated:
                self = .phoneDisconnected

            // 전송 계층이 감싼 에러는 껍질을 벗겨 원래 원인으로 분류한다 —
            // 안 그러면 위치·네트워크 실패가 전부 서버 실패 화면으로 흘러 안내가 틀린다.
            case .transportFailure(let underlying):
                self.init(classifying: underlying)

            // 페이로드·스키마·응답 불일치는 사용자가 원인을 구분해도 할 수 있는 일이 같다.
            // 재시도와 iPhone 대체 경로를 모두 가진 화면으로 보낸다.
            case .payloadTooLarge, .replyTimedOut, .malformedPayload,
                 .unsupportedSchemaVersion, .unexpectedReply, .unsupportedChannel, .remote:
                self = .checkInRequestFailed
            }

        case let locationError as CLError where locationError.code == .denied:
            self = .locationPermissionDenied

        // 권한 거부를 뺀 나머지 위치 에러는 코드를 가리지 않고 전부 "위치를 못 찾음"이다 —
        // 원인이 무엇이든 사용자가 할 수 있는 일(자리 옮기고 재시도)이 같고, 위치 실패를
        // 서버 실패 화면으로 흘리면 안내가 틀린다.
        case is CLError:
            self = .locationUnavailable

        case let urlError as URLError where urlError.code == .notConnectedToInternet:
            self = .offlineQueued

        default:
            self = .checkInRequestFailed
        }
    }
}

// MARK: - WatchLocationMeasurement

/// 위치 측정 타임아웃 상수. 실제 타이머는 위치 측정을 시작하는 #1207 이 소유하지만, P0-2 화면
/// 문구("15초 안에 위치를 찾지 못했습니다")와 실제 타임아웃 값이 어긋나지 않도록 이 이슈에서
/// 먼저 선언해 두 곳이 같은 값을 참조하게 한다.
enum WatchLocationMeasurement {
    static let timeout: Duration = .seconds(15)
}
