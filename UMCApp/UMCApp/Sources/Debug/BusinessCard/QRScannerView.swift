//
//  QRScannerView.swift
//  UMCApp
//
//  Created by One on 8/16/26.
//

#if DEBUG
import SwiftUI
import VisionKit

/// VisionKit `DataScannerViewController` 래퍼 — QR 문자열 하나를 읽어 콜백으로 넘긴다.
///
/// 검증 화면 전용이다. 제품 스캐너는 스캔 후 안내·재시도·중복 방지 UX가 필요하고,
/// 그건 명함 View 라운드 몫이다. 여기서는 "읽히는가"만 본다.
///
/// - Note: 제품 스캐너 도입 뒤에도 **이 타입은 남긴다.** 하네스는 명함 딥링크뿐 아니라
///   NI 토큰 QR(``NearbyRangingSection``)도 읽는데, 제품 스캐너는 명함 딥링크만 받고
///   그 위에 안내·재시도 UX 를 얹을 것이라 토큰 문자열을 그대로 넘겨주지 않는다.
///   제품 스캐너가 원문 문자열을 그대로 흘려주게 되면 그때 이 타입을 걷어낸다.
struct QRScannerView: UIViewControllerRepresentable {

    /// 같은 QR을 계속 읽어 콜백이 폭주하지 않도록, 직전과 다른 값일 때만 올린다.
    let onScanned: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        guard !controller.isScanning else { return }
        try? controller.startScanning()
    }

    static func dismantleUIViewController(
        _ controller: DataScannerViewController,
        coordinator: Coordinator
    ) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScanned: onScanned)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onScanned: (String) -> Void
        private var lastPayload: String?

        init(onScanned: @escaping (String) -> Void) {
            self.onScanned = onScanned
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            deliver(from: addedItems)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didUpdate updatedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            deliver(from: updatedItems)
        }

        private func deliver(from items: [RecognizedItem]) {
            for item in items {
                guard case .barcode(let barcode) = item,
                      let payload = barcode.payloadStringValue,
                      payload != lastPayload else { continue }
                lastPayload = payload
                onScanned(payload)
            }
        }
    }
}
#endif
