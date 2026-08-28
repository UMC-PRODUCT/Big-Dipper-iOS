//
//  BusinessCard3DSpike.swift
//  BusinessCardPresentation
//
//  Created by One on 8/28/26.
//

#if DEBUG
import BusinessCardDomain
import CoreGraphics
import Foundation
import Metal
import RealityKit
import UIKit
import UMCFoundation

/// 3D 명함 Phase 0 기술 검증(#1245) 하네스.
///
/// 설계서 §6 이 남긴 세 불확실성을 **실제로 돌려서** 재는 코드다. 제품 경로에서 부르지 않고
/// ``BusinessCard3DSpikeView`` 와 `BusinessCard3DSpikeTests` 만 호출한다.
///
/// | 축 | 재는 것 | 진입점 |
/// |---|---|---|
/// | 온디바이스 합성 | 프리미티브 조립 + USDZ 저장 | ``composeCard(_:photo:)`` · ``exportUSDZ(_:)`` |
/// | 한글 텍스트 메시 | `MeshResource.generateText` 바운즈·정점·시간 | ``probeKoreanText(fontSizes:)`` |
/// | 2D 스냅샷 | `RealityRenderer` 오프스크린 렌더 + 읽기 | ``renderSnapshot(of:pixelSize:)`` |
///
/// **베이스 USDZ 템플릿 에셋이 아직 없다**(#1246 이 3D 저작 필요로 제외됨). 그래서 카드 몸통은
/// `generateBox`, 사진 면은 `generatePlane` 프리미티브로 대체한다. 에셋이 도착하면
/// ``composeCard(_:photo:)`` 의 몸통 생성만 `Entity(named:in:)` 로 바꿔 같은 측정을 다시 돌린다.
///
/// 재현: `make test SCHEME=BusinessCardPresentation` — 측정치는 테스트 로그에 표로 찍힌다.
@MainActor
public enum BusinessCard3DSpike {

    // MARK: - Property

    /// 실물 명함 90×50mm 를 1:1 미터로 옮긴 카드 치수. RealityKit 좌표계는 미터다.
    public enum CardGeometry {
        public static let width: Float = 0.09
        public static let height: Float = 0.05
        public static let depth: Float = 0.0006
        public static let cornerRadius: Float = 0.003
    }

    /// 한글 렌더 품질을 볼 때 쓰는 표본. 실명이 아니라 글자 형태를 고르게 훑는 더미다.
    ///
    /// - `일반`·`네글자` — 흔한 이름 길이
    /// - `혼용` — 한글·라틴·숫자·중점이 한 줄에 섞였을 때 베이스라인
    /// - `복잡자모` — 종성 겹받침까지 있는 글자. 글리프가 뭉개지면 여기서 먼저 보인다
    /// - `NFD분해` — 자소 분리(U+1100 계열) 문자열. NFC 와 바운즈가 크게 다르면
    ///   서버·파일시스템에서 온 분해형 문자열이 그대로 메시로 가면 안 된다는 뜻이다
    public static let koreanSamples: [(label: String, string: String)] = [
        ("일반", "김유엠"),
        ("네글자", "박고은비"),
        ("긴이름", "황보정민아"),
        ("혼용", "iOS · 12기"),
        ("복잡자모", "뷁뾻쭑"),
        ("NFD분해", "김유엠".decomposedStringWithCanonicalMapping),
    ]

    // MARK: - Function

    /// 프로필 데이터를 카드 엔티티로 합성한다. 설계서 §6 의 1~4 단계를 프리미티브로 흉내 낸다.
    ///
    /// - Parameters:
    ///   - card: 바인딩할 프로필. 이름·파트·기수 세 줄이 텍스트 메시가 된다.
    ///   - photo: 프로필 사진. `nil` 이면 사진 면을 생략한다(실제 폴백 규칙은 #1248 소관).
    ///   - fontSize: 텍스트 메시 폰트 크기(미터). 기본값은 이름 줄 기준.
    public static func composeCard(
        _ card: MyCard,
        photo: CGImage? = nil,
        fontSize: CGFloat = 0.006
    ) throws -> ModelEntity {
        let body = ModelEntity(
            mesh: .generateBox(
                width: CardGeometry.width,
                height: CardGeometry.height,
                depth: CardGeometry.depth,
                cornerRadius: CardGeometry.cornerRadius
            ),
            materials: [UnlitMaterial(color: accentColor(for: card.part))]
        )
        body.name = "CardBody"

        let lines = [card.name, card.partDisplayName, "\(card.generation)기"]
        for (index, line) in lines.enumerated() {
            let label = ModelEntity(
                mesh: textMesh(line, fontSize: index == .zero ? fontSize : fontSize * 0.7),
                materials: [UnlitMaterial(color: .white)]
            )
            label.name = "Text_\(["name", "part", "generation"][index])"
            // 앵커 좌표는 임시다 — 실제 값은 #1246 의 템플릿 앵커 규약이 정한다.
            label.position = [
                -CardGeometry.width / 2 + 0.006,
                CardGeometry.height / 2 - 0.012 - Float(index) * 0.009,
                CardGeometry.depth / 2 + 0.0002,
            ]
            body.addChild(label)
        }

        if let photo {
            let side = CardGeometry.height * 0.5
            let plane = ModelEntity(
                mesh: .generatePlane(width: side, height: side, cornerRadius: side / 2),
                materials: [try photoMaterial(photo)]
            )
            plane.name = "PhotoPlane"
            plane.position = [
                CardGeometry.width / 2 - side / 2 - 0.006,
                .zero,
                CardGeometry.depth / 2 + 0.0002,
            ]
            body.addChild(plane)
        }

        return body
    }

    /// 한글 텍스트 메시를 폰트 크기별로 만들어 보고 바운즈·정점 수·소요 시간을 모은다.
    ///
    /// - Parameter fontSizes: 시험할 폰트 크기(미터). RealityKit 은 `generateText` 의 point size 를
    ///   미터로 해석하는데, 실물 명함 스케일(수 mm)은 CoreText 가 다루기엔 극단적으로 작아
    ///   글리프가 무너질 수 있다. 그래서 작은 값·큰 값을 같이 잰다.
    public static func probeKoreanText(
        fontSizes: [CGFloat] = [0.006, 0.05]
    ) -> [TextMeshProbe] {
        fontSizes.flatMap { size in
            koreanSamples.map { sample in
                let (elapsed, mesh) = measure { textMesh(sample.string, fontSize: size) }
                let extents = mesh.bounds.extents
                return TextMeshProbe(
                    label: sample.label,
                    string: sample.string,
                    fontSize: size,
                    milliseconds: elapsed,
                    extents: extents,
                    vertexCount: vertexCount(of: mesh),
                    characterCount: sample.string.count
                )
            }
        }
    }

    /// 엔티티를 오프스크린 텍스처에 렌더해 2D 이미지로 뽑는다. 명함첩 그리드 썸네일 경로(#1249).
    ///
    /// `RealityRenderer` 는 뷰 계층이 필요 없어 유닛 테스트에서도 돌고, 카드 저장 시점에 배치로
    /// 굽는 것도 가능하다 — 그래서 `ARView.snapshot` 대신 이 쪽을 잰다.
    public static func renderSnapshot(
        of entity: Entity,
        pixelSize: Int = 512
    ) async throws -> UIImage {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw SpikeError.noMetalDevice
        }
        let renderer = try RealityRenderer()
        renderer.entities.append(entity)

        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 30
        camera.position = [.zero, .zero, 0.2]
        renderer.entities.append(camera)
        renderer.activeCamera = camera
        renderer.cameraSettings.colorBackground = .color(UIColor.clear.cgColor)

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: pixelSize,
            height: pixelSize,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw SpikeError.textureAllocationFailed
        }

        let output = try RealityRenderer.CameraOutput(.singleProjection(colorTexture: texture))
        try await withCheckedThrowingContinuation { (continuation: RenderContinuation) in
            do {
                try renderer.updateAndRender(
                    deltaTime: 1.0 / 60.0,
                    cameraOutput: output,
                    onComplete: { _ in continuation.resume() }
                )
            } catch {
                continuation.resume(throwing: error)
            }
        }
        return try image(from: texture)
    }

    /// 합성한 엔티티를 온디바이스에서 USDZ 로 저장해 본다. 되면 파일 URL·바이트 수를 돌려준다.
    ///
    /// 설계서 §6 은 교환 페이로드에 USDZ 를 싣지 않기로 했으므로 이 경로는 **필수가 아니다.**
    /// 공유·내보내기 같은 후속 기능이 가능한지 미리 재 두는 것뿐이다.
    public static func exportUSDZ(_ entity: Entity) async throws -> ExportResult {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("spike-card-\(UUID().uuidString).usdz")
        let started = ContinuousClock.now
        try await entity.write(to: url)
        let elapsed = started.duration(to: .now)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = attributes[.size] as? Int ?? .zero
        return ExportResult(url: url, byteCount: size, milliseconds: elapsed.milliseconds)
    }

    /// 현재 프로세스의 물리 메모리 사용량(바이트). 합성 전후로 불러 증가분을 본다.
    public static func memoryFootprint() -> Int {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Int(info.phys_footprint) : .zero
    }

    /// 블록 실행 시간을 밀리초로 잰다.
    public static func measure<Value>(
        _ body: () -> Value
    ) -> (milliseconds: Double, value: Value) {
        let started = ContinuousClock.now
        let value = body()
        return (started.duration(to: .now).milliseconds, value)
    }

    // MARK: - Private

    private typealias RenderContinuation = CheckedContinuation<Void, any Error>

    private static func textMesh(_ string: String, fontSize: CGFloat) -> MeshResource {
        .generateText(
            string,
            extrusionDepth: Float(fontSize) * 0.05,
            font: .systemFont(ofSize: fontSize),
            containerFrame: .zero,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
        )
    }

    private static func photoMaterial(_ photo: CGImage) throws -> UnlitMaterial {
        let texture = try TextureResource(image: photo, options: .init(semantic: .color))
        var material = UnlitMaterial()
        material.color = .init(tint: .white, texture: .init(texture))
        return material
    }

    /// 파트별 악센트 컬러. 설계서 §6-4 룩업 테이블의 최소 형태다.
    ///
    /// 미정의 파트(`partRaw` 가 살아 있는 크로스 플랫폼 값)는 `.admin` 으로 떨어지므로 회색이
    /// 폴백이 된다 — 실제 색 매핑표는 #1246 에서 디자인팀이 확정한다.
    private static func accentColor(for part: UMCPartType) -> UIColor {
        switch part {
        case .admin:
            return .systemGray
        case .pm:
            return .systemPurple
        case .design:
            return .systemPink
        case .server:
            return .systemGreen
        case .front:
            return UIColor(red: 84 / 255, green: 104 / 255, blue: 252 / 255, alpha: 1)
        }
    }

    private static func vertexCount(of mesh: MeshResource) -> Int {
        mesh.contents.models.reduce(.zero) { total, model in
            total + model.parts.reduce(.zero) { $0 + $1.positions.count }
        }
    }

    private static func image(from texture: any MTLTexture) throws -> UIImage {
        let bytesPerRow = texture.width * 4
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
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let cgImage = CGImage(
                  width: texture.width,
                  height: texture.height,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: bytesPerRow,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: bitmapInfo,
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: false,
                  intent: .defaultIntent
              )
        else {
            throw SpikeError.imageConversionFailed
        }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Result Types

/// ``BusinessCard3DSpike/probeKoreanText(fontSizes:)`` 한 건의 결과.
public struct TextMeshProbe: Sendable {

    // MARK: - Property

    public let label: String
    public let string: String
    public let fontSize: CGFloat
    public let milliseconds: Double
    public let extents: SIMD3<Float>
    public let vertexCount: Int
    public let characterCount: Int

    // MARK: - Computed Property

    /// 바운즈가 사실상 0 이면 글리프가 아예 안 나온 것 — 폰트 fallback 실패 신호다.
    public var isDegenerate: Bool {
        extents.x < 1e-6 || extents.y < 1e-6
    }

    /// 글자당 정점 수. 글리프가 `.notdef` 네모로 대체되면 글자와 무관하게 값이 납작해진다.
    public var verticesPerCharacter: Double {
        characterCount > .zero ? Double(vertexCount) / Double(characterCount) : .zero
    }
}

/// ``BusinessCard3DSpike/exportUSDZ(_:)`` 결과.
public struct ExportResult: Sendable {
    public let url: URL
    public let byteCount: Int
    public let milliseconds: Double
}

/// 하네스가 환경 때문에 진행 못 할 때 던지는 에러. 실패 자체가 검증 결과다.
public enum SpikeError: Error {
    case noMetalDevice
    case textureAllocationFailed
    case imageConversionFailed
}

extension Duration {

    /// 밀리초 실수값. 측정 로그를 사람이 읽는 단위로 맞춘다.
    var milliseconds: Double {
        Double(components.seconds) * 1_000
            + Double(components.attoseconds) / 1_000_000_000_000_000
    }
}
#endif
