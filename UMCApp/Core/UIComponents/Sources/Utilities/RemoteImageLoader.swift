//
//  RemoteImageLoader.swift
//  CoreUIComponents
//

import CoreGraphics
import Foundation
import Kingfisher

/// URL 문자열에서 이미지를 받아 `CGImage` 로 돌려준다.
///
/// ``RemoteImage`` 의 헤드리스 판 — 뷰 없이 픽셀만 필요한 곳(3D 텍스처 등)에서 쓴다.
/// 다운로드·디스크 캐시·같은 URL 중복 요청 병합은 Kingfisher 가 이미 한다.
/// 여기서 다시 하지 않는다.
public enum RemoteImageLoader {

    // MARK: - Function

    /// - Parameters:
    ///   - urlString: 이미지 주소. 파싱되지 않으면 `nil` 을 돌려준다.
    ///   - maxPixelSize: 다운샘플 목표 **픽셀**(긴 변 기준). 원본이 이보다 작으면 원본 그대로다.
    /// - Returns: 디코드된 이미지. 받지 못하면 `nil`.
    ///
    /// **실패를 던지지 않는 것이 이 함수의 계약이다.** 호출부에서 「사진이 없다」와
    /// 「사진을 못 받았다」는 같은 화면(자리표시자)으로 끝나므로 구분할 이유가 없다.
    /// 구분이 필요한 실패는 이 아래가 아니라 이 위(합성·렌더)에서 던진다.
    public static func cgImage(from urlString: String, maxPixelSize: CGFloat) async -> CGImage? {
        guard let url = URL(string: urlString) else { return nil }

        // `DownsamplingImageProcessor` 는 크기를 pt 로 보고 스케일을 곱한다
        // (`Kingfisher/Sources/Image/Image.swift` — `max(w, h) * scale`).
        // 화면 스케일이 아니라 1 로 고정해야 결과 픽셀이 `maxPixelSize` 가 된다.
        let options: KingfisherOptionsInfo = [
            .processor(DownsamplingImageProcessor(
                size: CGSize(width: maxPixelSize, height: maxPixelSize)
            )),
            .scaleFactor(1)
        ]

        do {
            let result = try await KingfisherManager.shared
                .retrieveImage(with: url, options: options)
            return result.image.cgImage
        } catch {
            // 취소도 여기로 온다(`KingfisherError.requestError(.taskCancelled)`).
            // 취소를 실제로 흘려야 하는 쪽은 이 값을 쓰는 합성기이고, 거기서
            // `Task.checkCancellation()` 이 다시 확인한다.
            return nil
        }
    }
}
