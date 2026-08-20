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
