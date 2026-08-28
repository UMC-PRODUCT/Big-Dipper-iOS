//
//  CardScanViewModel.swift
//  BusinessCardPresentation
//
//  Created by One on 8/28/26.
//

import AVFoundation
import Foundation
import BusinessCardDomain

// MARK: - Constants

private enum Constants {
    static let notCardNotice = "UMC 명함 QR이 아니에요. 상대의 명함 QR을 비춰 주세요."
}

/// 인앱 QR 스캔 화면 상태 (#1224).
///
/// 카메라를 켤 수 없는 두 이유를 나눠 둔다 — 「권한 거부」는 사용자가 설정에서 되돌릴 수
/// 있고 「미지원 기기」는 되돌릴 수 없다. 한 상태로 합치면 못 고치는 안내를 띄우게 된다.
public enum CardScanState: Equatable {

    /// 지원 여부·권한을 확인하는 중.
    case preparing

    /// 카메라가 돌고 있다.
    case scanning

    /// 카메라 권한이 거부됐다 (설정에서 되돌릴 수 있다).
    case denied

    /// 데이터 스캐너를 지원하지 않는 기기 (A12 미만·시뮬레이터).
    case unsupported
}

/// 인앱 QR 스캐너 (#1224).
///
/// 스캔한 문자열을 ``CardLink`` 로 해석하는 데까지가 이 ViewModel 의 일이다. 조회·저장·
/// 완료 화면은 딥링크와 **같은** 경로(``CardLinkReceiver``)로 넘긴다 — 저장 규칙이 두 벌로
/// 갈리면 명함첩 중복 판정·자기 명함 제외가 경로마다 달라진다.
///
/// - Important: `@MainActor` — 카메라 권한 상태와 화면 상태를 함께 다룬다.
@MainActor
@Observable
public final class CardScanViewModel {

    // MARK: - Property

    public private(set) var state: CardScanState = .preparing

    /// 명함이 아닌 QR 을 읽었을 때의 안내. 스캔은 멈추지 않는다 — 카메라를 껐다 켜게 하는
    /// 것보다 그대로 다음 QR 을 기다리는 편이 짧다.
    public private(set) var notice: String?

    /// 해석에 성공한 링크. ``CardLinkReceiver`` 가 가져가 처리한 뒤 `nil` 로 비운다.
    public var scannedLink: CardLink?

    // MARK: - Init

    public init() {}

    // MARK: - Function

    /// 지원 여부 → 권한 순으로 확인한다. 미지원 기기에 권한 팝업을 띄우지 않으려는 순서다.
    public func prepare() async {
        guard QRScannerView.isSupported else {
            state = .unsupported
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            state = .scanning

        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            state = granted ? .scanning : .denied

        case .denied, .restricted:
            state = .denied

        @unknown default:
            state = .denied
        }
    }

    /// 인식한 문자열을 명함 링크로 해석한다. 명함 QR 이 아니면 안내만 남기고 계속 스캔한다.
    public func handle(payload: String) {
        guard let url = URL(string: payload), let link = CardLink.parse(url) else {
            notice = Constants.notCardNotice
            return
        }

        notice = nil
        scannedLink = link
    }
}
