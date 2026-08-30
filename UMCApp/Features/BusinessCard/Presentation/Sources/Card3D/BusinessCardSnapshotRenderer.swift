//
//  BusinessCardSnapshotRenderer.swift
//  BusinessCardPresentation
//
//  Created by One on 8/30/26.
//

import BusinessCardDomain
import CoreGraphics
import Foundation
import Metal
import RealityKit
import UIKit

/// 카드 엔티티를 만드는 합성기의 자리. 함수 타입이라 프로토콜·구현체·DI 등록이 필요 없다 —
/// 이 seam 의 목적은 「#1248 이 오면 한 번 갈아 끼우기」와 「테스트가 스텁을 꽂기」뿐이다.
typealias BusinessCardEntityComposing =
    @MainActor (_ card: MyCard, _ portrait: CGImage?) async throws -> Entity

/// 카드 엔티티를 오프스크린 텍스처에 렌더해 2D 이미지로 뽑는다 (스파이크 축 3 의 제품 승격판).
///
/// 뷰 계층이 없는 `RealityRenderer` 만 쓴다 — 그리드는 `RealityView` 를 **절대 만들지 않는다.**
/// 셀마다 3D 뷰를 띄우면 스크롤이 끊긴다는 것이 #1245 의 결론이고, #1249 는 그 경로를 없애는
/// 것이 목적이다.
@MainActor
enum BusinessCardSnapshotRenderer {

    // MARK: - Property

    /// **#1248 교체 지점** — `BusinessCardComposer` 가 머지되면 이 한 줄만 갈아끼우면 제품 전
    /// 경로가 새 합성기를 탄다. 합성기를 넘기지 않은 호출은 전부 ``render(_:portrait:pixelSize:compose:)``
    /// 본문에서 이 값으로 풀린다. 앱 버전이 캐시 키에 들어 있어 옛 스냅샷은 릴리스와 함께 자동
    /// 무효화되므로 마이그레이션 코드가 필요 없다.
    static let defaultComposing: BusinessCardEntityComposing = BusinessCardSnapshotComposer.compose

    private enum Metrics {
        /// 스파이크가 쓴 값. 좁을수록 원근 왜곡이 줄어 카드가 평면 썸네일처럼 보인다.
        static let fieldOfViewDegrees: Float = 30
        /// 카드가 프레임에서 차지하는 비율. 나머지 8% 는 가장자리가 잘리지 않게 두는 여백이다.
        static let fillRatio: Float = 0.92
        /// 합성이 빈 엔티티를 주면 바운즈가 0 이라 카메라가 원점에 붙는다. 그 경우의 바닥값.
        static let minimumFrameHeight: Float = 0.01
        static let bytesPerPixel = 4
        static let bitsPerComponent = 8
        static let frameDuration: Double = 1.0 / 60.0
    }

    // MARK: - Function

    /// 카드 한 장을 굽는다. 취소되면 `CancellationError` 를 던진다 — 호출부는 이것을 실패와
    /// 구분해 실패 기억에 넣지 않는다.
    ///
    /// - Parameters:
    ///   - card: 앞면에 찍을 프로필.
    ///   - portrait: 프로필 사진. develop 단계에서는 항상 `nil` 이다 (§11 교체 지점 2).
    ///   - pixelSize: 산출 픽셀 크기. 캐시 키 컴포넌트라 바꾸면 전량 자동 무효화된다.
    ///   - compose: 카드 엔티티 합성기. `nil` 이면 ``defaultComposing``.
    static func render(
        _ card: MyCard,
        portrait: CGImage?,
        pixelSize: CGSize,
        compose: BusinessCardEntityComposing? = nil
    ) async throws -> UIImage {
        try Task.checkCancellation()
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw BusinessCardSnapshotError.noMetalDevice
        }

        // 기본 인자 표현식은 호출자 격리로 평가돼서 `defaultComposing`(MainActor)을 거기 두면
        // Swift 6 언어 모드에서 에러다. 이미 MainActor 인 본문에서 푼다.
        let entity = try await (compose ?? defaultComposing)(card, portrait)
        // 합성이 끝난 시점이 취소를 볼 수 있는 마지막 값싼 지점이다. 여기서부터는 GPU 가 돈다.
        try Task.checkCancellation()

        let renderer = try RealityRenderer()
        renderer.entities.append(entity)
        let camera = makeCamera(framing: entity, pixelSize: pixelSize)
        renderer.entities.append(camera)
        renderer.activeCamera = camera
        // 배경을 투명하게 둬야 셀이 카드 모서리 바깥을 자기 배경으로 채울 수 있다.
        renderer.cameraSettings.colorBackground = .color(UIColor.clear.cgColor)

        let texture = try makeTexture(device: device, pixelSize: pixelSize)
        let output = try RealityRenderer.CameraOutput(.singleProjection(colorTexture: texture))
        try await withCheckedThrowingContinuation { (continuation: RenderContinuation) in
            do {
                try renderer.updateAndRender(
                    deltaTime: Metrics.frameDuration,
                    cameraOutput: output,
                    onComplete: { _ in continuation.resume() }
                )
            } catch {
                continuation.resume(throwing: error)
            }
        }
        return try await image(from: copyBytes(from: texture), pixelSize: pixelSize)
    }

    // MARK: - Private

    private typealias RenderContinuation = CheckedContinuation<Void, any Error>

    /// 카메라를 엔티티 바운즈에서 역산한다 — 카드 치수를 상수로 들고 있지 않으므로 #1248 의
    /// USDZ 템플릿으로 합성기가 바뀌어도(치수가 달라져도) 프레이밍 코드는 그대로 산다.
    private static func makeCamera(
        framing entity: Entity,
        pixelSize: CGSize
    ) -> PerspectiveCamera {
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = Metrics.fieldOfViewDegrees

        let bounds = entity.visualBounds(relativeTo: nil)
        let aspect = Float(pixelSize.width / pixelSize.height)
        // 카드 비(1.8)와 프레임 비(1.78)가 어긋나므로 가로·세로 중 먼저 차는 쪽에 맞춘다.
        let frameHeight = max(
            bounds.extents.y,
            bounds.extents.x / aspect,
            Metrics.minimumFrameHeight
        ) / Metrics.fillRatio
        // `fieldOfViewOrientation` 기본값이 `.vertical` 이라 세로 화각으로 거리를 푼다.
        let halfAngle = Metrics.fieldOfViewDegrees / 2 * .pi / 180
        let distance = frameHeight / 2 / tan(halfAngle)

        camera.position = bounds.center + [.zero, .zero, distance]
        return camera
    }

    private static func makeTexture(
        device: any MTLDevice,
        pixelSize: CGSize
    ) throws -> any MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: Int(pixelSize.width),
            height: Int(pixelSize.height),
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw BusinessCardSnapshotError.textureAllocationFailed
        }
        return texture
    }

    /// 텍스처 읽기는 메인 액터에서 동기로 끝낸다. `MTLTexture` 에는 `Sendable` 마킹이 없어서
    /// 액터 경계를 넘기면 Swift 6 언어 모드에서 컴파일 에러다 — 경계를 넘는 것은 `Data` 뿐이다.
    /// `onComplete` 이후에만 부르므로 렌더러와 텍스처를 두고 경합하지 않는다.
    private static func copyBytes(from texture: any MTLTexture) -> Data {
        let bytesPerRow = texture.width * Metrics.bytesPerPixel
        var bytes = [UInt8](repeating: .zero, count: bytesPerRow * texture.height)
        bytes.withUnsafeMutableBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            texture.getBytes(
                base,
                bytesPerRow: bytesPerRow,
                from: MTLRegionMake2D(.zero, .zero, texture.width, texture.height),
                mipmapLevel: .zero
            )
        }
        return Data(bytes)
    }

    /// 비트맵 조립은 액터 격리가 없다. `nonisolated async` 라 호출부가 메인 액터여도 글로벌
    /// 실행자에서 돈다 — 이 경로에서 메인 스레드 밖으로 뺄 수 있는 유일한 조각이다.
    private nonisolated static func image(
        from bytes: Data,
        pixelSize: CGSize
    ) async throws -> UIImage {
        let width = Int(pixelSize.width)
        let height = Int(pixelSize.height)
        let bytesPerRow = width * Metrics.bytesPerPixel
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let provider = CGDataProvider(data: bytes as CFData),
              let cgImage = CGImage(
                  width: width,
                  height: height,
                  bitsPerComponent: Metrics.bitsPerComponent,
                  bitsPerPixel: Metrics.bitsPerComponent * Metrics.bytesPerPixel,
                  bytesPerRow: bytesPerRow,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: bitmapInfo,
                  provider: provider,
                  decode: nil,
                  // 512px 원본이 셀 폭(@2x 기준 362px)으로 축소되는 경로다. 꺼 두면 얇은 획이
                  // 통째로 드롭된다.
                  shouldInterpolate: true,
                  intent: .defaultIntent
              )
        else {
            throw BusinessCardSnapshotError.imageConversionFailed
        }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Error

/// 굽기가 환경 때문에 진행 못 할 때 던진다.
///
/// 사용자에게 보여주지 않으므로 메시지를 갖지 않는다 — 실패하면 화면은 조용히 기존 2D 셀을
/// 유지한다(정보 손실 0). `ErrorHandler` 전역 Alert 로 올리지 않는 이유이기도 하다.
enum BusinessCardSnapshotError: Error {
    case noMetalDevice
    case textureAllocationFailed
    case imageConversionFailed
}
