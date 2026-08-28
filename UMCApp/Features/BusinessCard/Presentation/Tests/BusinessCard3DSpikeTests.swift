//
//  BusinessCard3DSpikeTests.swift
//  BusinessCardPresentationTests
//
//  Created by One on 8/28/26.
//

import CoreGraphics
import Foundation
import RealityKit
import Testing
import UIKit
import BusinessCardDomain
@testable import BusinessCardPresentation

/// 3D 명함 Phase 0 기술 검증(#1245)의 측정 러너.
///
/// 단정하는 것은 **Go/No-Go 를 가르는 최소 조건** 뿐이다 — 한글 메시가 비어 있지 않을 것,
/// 스냅샷이 빈 화면이 아닐 것. 나머지 수치(시간·메모리·바이트)는 로그로 찍어 이슈 코멘트와
/// `docs/claude/business-card-3d-spike.md` 로 옮긴다.
///
/// 메모리 증가분은 프로세스 전역 `phys_footprint` 차이라서 다른 테스트가 동시에 RealityKit 을
/// 만지면 오염된다. 그래서 `.serialized` 로 묶는다 — 수치의 신뢰도가 병렬 실행 속도보다 중요하다.
///
/// 실행: `cd UMCApp && make test SCHEME=BusinessCardPresentation`
@MainActor
@Suite("BusinessCard3D 스파이크 — 합성·한글 메시·2D 스냅샷", .serialized)
struct BusinessCard3DSpikeTests {

    // MARK: - 축 1. 온디바이스 합성

    @Test("프로필 3줄과 사진이 실제로 카드 엔티티에 붙는다")
    func composeBindsProfileFields() throws {
        let before = BusinessCard3DSpike.memoryFootprint()
        let (elapsed, entity) = try BusinessCard3DSpike.measureThrowing {
            try BusinessCard3DSpike.composeCard(card, photo: makePhoto())
        }
        let after = BusinessCard3DSpike.memoryFootprint()

        let names = entity.children.map(\.name).sorted()
        #expect(names == ["PhotoPlane", "Text_generation", "Text_name", "Text_part"])
        #expect(entity.model?.mesh != nil)

        report("""
            [축1 합성] 1장 조립 \(elapsed.decimals(2))ms · \
            메모리 증가 \((after - before) / 1_024)KB · 자식 \(entity.children.count)개
            """)
    }

    @Test("사진이 없어도 합성이 성공한다")
    func composeWithoutPhoto() throws {
        let entity = try BusinessCard3DSpike.composeCard(card, photo: nil)

        #expect(entity.children.contains { $0.name == "Text_name" })
        #expect(!entity.children.contains { $0.name == "PhotoPlane" })
    }

    @Test("두 번째 합성부터의 비용과 사진 텍스처 메모리 몫을 기록한다")
    func warmComposeCostAndTextureMemory() throws {
        // 첫 합성에는 RealityKit 초기화가 통째로 실려 실제 카드 조립 비용을 가린다. 버린다.
        _ = try BusinessCard3DSpike.composeCard(card, photo: makePhoto())

        let photo = makePhoto()
        let withPhoto = try measureCompose(repeats: warmComposeRepeats) {
            try BusinessCard3DSpike.composeCard(card, photo: photo)
        }
        let withoutPhoto = try measureCompose(repeats: warmComposeRepeats) {
            try BusinessCard3DSpike.composeCard(card, photo: nil)
        }

        for (label, run) in [("사진 포함", withPhoto), ("사진 제외", withoutPhoto)] {
            report("""
                [축1 웜합성] \(label) \(warmComposeRepeats)회 평균 \
                \(run.averageMilliseconds.decimals(2))ms · 메모리 증가 \(run.memoryDeltaBytes / 1_024)KB
                """)
        }

        let textureMilliseconds = withPhoto.averageMilliseconds - withoutPhoto.averageMilliseconds
        let textureBytes = (withPhoto.memoryDeltaBytes - withoutPhoto.memoryDeltaBytes)
            / warmComposeRepeats
        report("""
            [축1 텍스처] 512px 사진 1장 몫 — 시간 \(textureMilliseconds.decimals(2))ms · \
            메모리 \(textureBytes / 1_024)KB
            """)

        #expect(withPhoto.averageMilliseconds > .zero)
    }

    @Test("온디바이스 USDZ 저장 가능 여부를 기록한다")
    func exportUSDZ() async throws {
        let entity = try BusinessCard3DSpike.composeCard(card, photo: makePhoto())

        do {
            let result = try await BusinessCard3DSpike.exportUSDZ(entity)
            report("""
                [축1 USDZ] 저장 성공 · \(result.milliseconds.decimals(1))ms · \
                \(result.byteCount / 1_024)KB · \(result.url.lastPathComponent)
                """)
            #expect(result.byteCount > .zero)
            try? FileManager.default.removeItem(at: result.url)
        } catch {
            // 실패도 결론이다 — 저장이 안 되면 공유/내보내기 후속 기능이 서버 렌더를 필요로 한다.
            report("[축1 USDZ] 저장 실패 · \(error)")
        }
    }

    // MARK: - 축 2. 한글 텍스트 메시

    @Test("한글 표본이 빈 메시로 떨어지지 않는다")
    func koreanTextIsNotDegenerate() {
        let probes = BusinessCard3DSpike.probeKoreanText()

        report("[축2 한글] label | 폰트mm | ms | 가로×세로mm | 정점 | 글자당정점")
        for probe in probes {
            report("""
                [축2 한글] \(probe.label) | \((probe.fontSize * 1_000).decimals(1)) | \
                \(probe.milliseconds.decimals(2)) | \
                \((Double(probe.extents.x) * 1_000).decimals(2))×\
                \((Double(probe.extents.y) * 1_000).decimals(2)) | \
                \(probe.vertexCount) | \(probe.verticesPerCharacter.decimals(0))
                """)
        }

        let degenerate = probes.filter(\.isDegenerate).map(\.label)
        #expect(degenerate.isEmpty, "빈 메시로 떨어진 표본: \(degenerate)")
    }

    @Test("NFD 자소 분해 문자열도 NFC 와 같은 크기로 렌더된다")
    func decomposedHangulMatchesComposed() throws {
        let probes = BusinessCard3DSpike.probeKoreanText(fontSizes: [0.05])
        let composed = try #require(probes.first { $0.label == "일반" })
        let decomposed = try #require(probes.first { $0.label == "NFD분해" })

        let ratio = Double(decomposed.extents.x / composed.extents.x)
        report("""
            [축2 자소] NFC \(composed.extents.x.decimals(4))mm vs \
            NFD \(decomposed.extents.x.decimals(4))mm — 비 \(ratio.decimals(3))
            """)

        // CoreText 가 분해형을 결합해 그리면 폭이 같다. 자소가 낱글자로 흩어지면 폭이 크게 는다.
        #expect(ratio > 0.9 && ratio < 1.1, "NFD 문자열에서 자소 분리 발생 — 합성 전 NFC 정규화 필요")
    }

    // MARK: - 축 3. 2D 스냅샷

    @Test("스냅샷이 빈 이미지가 아니고, 1장 비용을 기록한다")
    func snapshotProducesVisiblePixels() async throws {
        let entity = try BusinessCard3DSpike.composeCard(card, photo: makePhoto())

        let started = ContinuousClock.now
        let image = try await BusinessCard3DSpike.renderSnapshot(of: entity, pixelSize: 512)
        let elapsed = started.duration(to: .now).milliseconds

        let opaqueRatio = try opaquePixelRatio(of: image)
        let pngBytes = image.pngData()?.count ?? .zero
        report("""
            [축3 스냅샷] 512px 1장 \(elapsed.decimals(2))ms · PNG \(pngBytes / 1_024)KB · \
            불투명 픽셀 \((opaqueRatio * 100).decimals(1))%
            """)

        #expect(opaqueRatio > 0.01, "렌더 결과가 사실상 빈 화면 — RealityRenderer 경로 불가")
    }

    @Test("명함첩 그리드 20장 스냅샷 총 비용을 기록한다")
    func gridSnapshotCost() async throws {
        let photo = makePhoto()
        let before = BusinessCard3DSpike.memoryFootprint()
        let started = ContinuousClock.now
        var totalBytes = 0

        for index in 0..<gridCardCount {
            let entity = try BusinessCard3DSpike.composeCard(card(at: index), photo: photo)
            let image = try await BusinessCard3DSpike.renderSnapshot(of: entity, pixelSize: 256)
            totalBytes += image.pngData()?.count ?? .zero
        }

        let elapsed = started.duration(to: .now).milliseconds
        let after = BusinessCard3DSpike.memoryFootprint()
        report("""
            [축3 그리드] 256px × \(gridCardCount)장 총 \(elapsed.decimals(1))ms \
            (장당 \((elapsed / Double(gridCardCount)).decimals(2))ms) · \
            PNG 합계 \(totalBytes / 1_024)KB · 메모리 증가 \((after - before) / 1_024)KB
            """)

        #expect(totalBytes > .zero)
    }

    // MARK: - Private

    /// 설계서 §5.4 그리드가 한 화면에 담는 장수 상한. 이슈 완료 조건의 "20장" 이다.
    private let gridCardCount = 20

    /// 웜 합성 평균을 낼 반복 횟수. 한 번 값은 스케줄러 노이즈에 흔들려 몫 계산이 무의미해진다.
    private let warmComposeRepeats = 10

    private var card: MyCard { BusinessCardPreviewData.myCard }

    /// 같은 합성을 여러 번 돌려 평균 시간과 누적 메모리 증가를 잰다.
    private func measureCompose(
        repeats: Int,
        _ body: () throws -> ModelEntity
    ) rethrows -> (averageMilliseconds: Double, memoryDeltaBytes: Int) {
        let before = BusinessCard3DSpike.memoryFootprint()
        let started = ContinuousClock.now
        for _ in 0..<repeats {
            _ = try body()
        }
        let elapsed = started.duration(to: .now).milliseconds
        return (elapsed / Double(repeats), BusinessCard3DSpike.memoryFootprint() - before)
    }

    /// 그리드 측정용으로 서로 다른 프로필을 돌려 쓴다 — 이름 길이·파트가 섞여야 비용이
    /// 한쪽으로 치우치지 않는다.
    private func card(at index: Int) -> MyCard {
        let cards = BusinessCardPreviewData.receivedCards
        return cards[index % cards.count].profile
    }

    /// 프로필 사진 대역. 실제 아바타 크기(512px 정사각)를 흉내 낸다.
    private func makePhoto(side: Int = 512) -> CGImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let image = renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            UIColor.white.setFill()
            context.cgContext.fillEllipse(
                in: CGRect(x: side / 4, y: side / 4, width: side / 2, height: side / 2)
            )
        }
        return image.cgImage!
    }

    /// 알파가 실제로 칠해진 픽셀 비율. 0 에 가까우면 렌더가 아무것도 안 그린 것이다.
    private func opaquePixelRatio(of image: UIImage) throws -> Double {
        let cgImage = try #require(image.cgImage)
        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let context = try #require(
            CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo
            )
        )
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let opaque = stride(from: 3, to: pixels.count, by: 4).reduce(into: 0) { count, index in
            if pixels[index] > 8 { count += 1 }
        }
        return Double(opaque) / Double(width * height)
    }

    /// 측정치는 실패가 아니라 산출물이므로 로그로 남긴다.
    private func report(_ line: String) {
        print("SPIKE#1245 \(line)")
    }
}

// MARK: - Test Helpers

private extension BinaryFloatingPoint {

    /// 로그 표에 찍을 고정 소수 문자열.
    func decimals(_ fractionDigits: Int) -> String {
        String(format: "%.\(fractionDigits)f", Double(self))
    }
}

extension BusinessCard3DSpike {

    /// throwing 클로저용 ``measure(_:)``. 테스트에서만 쓴다.
    static func measureThrowing<Value>(
        _ body: () throws -> Value
    ) rethrows -> (milliseconds: Double, value: Value) {
        let started = ContinuousClock.now
        let value = try body()
        return (started.duration(to: .now).milliseconds, value)
    }
}
