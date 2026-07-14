//
//  BLETransport.swift
//  CoreNearbyExchange
//
//  Created by euijjang97 on 4/23/26.
//

import Foundation
import CoreBluetooth

// MARK: - Constants

fileprivate enum Constants {
    /// UMC 명함 교환 전용 서비스 UUID (128-bit — 실제 UUID는 서버팀과 협의 후 확정)
    static let serviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    /// GATT 풀 JSON 수신 Characteristic UUID
    static let payloadCharacteristicUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    /// 광고 자동 종료 타이머 (PRD Q4: 5분)
    static let advertisingTimeout: TimeInterval = 5 * 60
}

// MARK: - BLETransport

/// Phase 1 BLE 전송 구현체.
///
/// Central: 주변 UMC 명함 피어를 스캔하고 GATT로 풀 페이로드 수신.
/// Peripheral: 자신의 명함 광고 UUID를 브로드캐스트.
///
/// 실제 데이터 송수신(GATT read/write 완결 로직)은 후속 이슈에서 구현 예정.
public final class BLETransport: NSObject, NearbyTransportProtocol {

    // MARK: - Property

    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?
    private var advertisingTimer: Task<Void, Never>?

    private var peerContinuation: AsyncStream<DiscoveredPeer>.Continuation?
    private var receiveContinuation: AsyncStream<ExchangePayload>.Continuation?

    private var isAdvertising = false

    // MARK: - Init

    public override init() {
        super.init()
    }

    // MARK: - NearbyTransportProtocol

    public func startAdvertising(payload: BLEAdvertisementPayload) async throws {
        guard !isAdvertising else { return }

        // PeripheralManager를 메인 큐가 아닌 전용 큐에서 초기화해 UI를 블로킹하지 않음
        let queue = DispatchQueue(label: "dev.umc.ble.peripheral", qos: .userInitiated)
        let manager = CBPeripheralManager(delegate: self, queue: queue)
        self.peripheralManager = manager

        // TODO: PeripheralManager 상태가 .poweredOn이 될 때까지 대기 후 광고 시작.
        // 현재는 보일러플레이트 구조만 수립; 실제 광고 데이터 구성은 후속 이슈.
        // 광고 데이터 형식: [CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
        //                    CBAdvertisementDataLocalNameKey: "UMC-\(cardUUIDPrefix.hex)"]

        isAdvertising = true

        // PRD Q4: 5분 타이머 후 자동 종료
        advertisingTimer = Task {
            try? await Task.sleep(for: .seconds(Constants.advertisingTimeout))
            await stopAdvertising()
        }
    }

    public func stopAdvertising() async {
        advertisingTimer?.cancel()
        advertisingTimer = nil
        // TODO: peripheralManager?.stopAdvertising()
        peripheralManager = nil
        isAdvertising = false
    }

    public func startScanning() -> AsyncStream<DiscoveredPeer> {
        AsyncStream { continuation in
            self.peerContinuation = continuation

            let queue = DispatchQueue(label: "dev.umc.ble.central", qos: .userInitiated)
            let manager = CBCentralManager(delegate: self, queue: queue)
            self.centralManager = manager

            // TODO: Central 상태가 .poweredOn이 되면 scanForPeripherals 호출.
            // 스캔 옵션: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            // 발견 시 didDiscoverPeripheral delegate에서 continuation.yield(peer) 호출.

            continuation.onTermination = { [weak self] _ in
                self?.centralManager?.stopScan()
                self?.centralManager = nil
                self?.peerContinuation = nil
            }
        }
    }

    public func send(payload: ExchangePayload, to peer: DiscoveredPeer) async throws {
        // TODO: 대상 피어에 연결(connect) → GATT 서비스 탐색 →
        //        payloadCharacteristicUUID write → 연결 해제.
        // 실제 데이터 송수신은 후속 이슈에서 구현.
        throw NearbyError.notImplemented
    }

    public func receive() -> AsyncStream<ExchangePayload> {
        AsyncStream { continuation in
            self.receiveContinuation = continuation
            // TODO: GATT characteristic notification 구독 시 수신 데이터를
            //        ExchangePayload.decode(from:) 거쳐 continuation.yield 호출.
            continuation.onTermination = { [weak self] _ in
                self?.receiveContinuation = nil
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLETransport: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            central.scanForPeripherals(
                withServices: [Constants.serviceUUID],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
        case .unauthorized:
            peerContinuation?.finish()
        default:
            break
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        // TODO: advertisementData에서 BLEAdvertisementPayload를 파싱해 DiscoveredPeer 생성.
        // 현재는 UUID prefix를 peripheral.identifier 기반으로 임시 구성.
        let peerID = peripheral.identifier.uuidString
        let peer = DiscoveredPeer(
            id: peerID,
            cardUUIDPrefix: Data(peerID.utf8.prefix(8)),
            version: 1,
            flags: 0
        )
        peerContinuation?.yield(peer)
    }
}

// MARK: - CBPeripheralManagerDelegate

extension BLETransport: CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral.state == .poweredOn else { return }
        // TODO: 광고 데이터 구성 및 peripheral.startAdvertising 호출.
        //        GATT 서비스/Characteristic 등록 포함.
    }
}
