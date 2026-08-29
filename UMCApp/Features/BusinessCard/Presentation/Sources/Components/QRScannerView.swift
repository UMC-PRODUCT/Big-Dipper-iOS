//
//  QRScannerView.swift
//  BusinessCardPresentation
//
//  Created by One on 8/16/26.
//

import SwiftUI
import VisionKit

/// VisionKit `DataScannerViewController` 래퍼 — QR 문자열 하나를 읽어 콜백으로 넘긴다.
///
/// 카메라 미리보기와 인식만 맡는다. 권한 확인·해석·재시도 안내는 이 뷰를 놓는 화면의
/// 몫이다 (제품 경로는 ``CardScanView``·``CardScanViewModel``).
///
/// - Important: `isSupported` 가 `false` 인 기기(A12 미만·시뮬레이터)에서는 만들지 않는다.
///   컨트롤러 생성 자체는 되지만 `startScanning()` 이 던져 화면이 검게 남는다.
public struct QRScannerView: UIViewControllerRepresentable {

    // MARK: - Property

    /// 같은 QR을 계속 읽어 콜백이 폭주하지 않도록, 직전과 다른 값일 때만 올린다.
    private let onScanned: (String) -> Void

    /// 이 기기에서 데이터 스캐너를 쓸 수 있는지. Neural Engine 이 필요해 시뮬레이터는 `false`.
    public static var isSupported: Bool { DataScannerViewController.isSupported }

    // MARK: - Init

    public init(onScanned: @escaping (String) -> Void) {
        self.onScanned = onScanned
    }

    // MARK: - Function

    public func makeUIViewController(context: Context) -> DataScannerViewController {
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

    public func updateUIViewController(
        _ controller: DataScannerViewController,
        context: Context
    ) {
        guard !controller.isScanning else { return }
        try? controller.startScanning()
    }

    public static func dismantleUIViewController(
        _ controller: DataScannerViewController,
        coordinator: Coordinator
    ) {
        controller.stopScanning()
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onScanned: onScanned)
    }

    // MARK: - Coordinator

    public final class Coordinator: NSObject, DataScannerViewControllerDelegate {

        private let onScanned: (String) -> Void
        private var lastPayload: String?

        init(onScanned: @escaping (String) -> Void) {
            self.onScanned = onScanned
        }

        public func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            deliver(from: addedItems)
        }

        public func dataScanner(
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
