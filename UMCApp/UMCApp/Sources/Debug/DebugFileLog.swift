//
//  DebugFileLog.swift
//  UMCApp
//
//  Created by One on 8/18/26.
//

#if DEBUG
import Foundation

/// 검증 이벤트를 앱 컨테이너 파일로 남긴다.
///
/// **왜 파일인가**: 화면에만 쌓아 두면 맥에서 읽을 방법이 없다. 실기기 검증마다 사람에게
/// 화면을 읽어 달라고 부탁하게 되고, 확인 한 번에 왕복이 한 번씩 붙는다. 파일로 남기면
/// 이렇게 꺼내 볼 수 있다:
///
/// ```bash
/// xcrun devicectl device copy from --device <id> \
///   --domain-type appDataContainer --domain-identifier dev.umc.product.debug \
///   --source "Library/Caches/umc-debug-events.log" --destination .
/// ```
///
/// `os_log` 로는 안 된다 — 콘솔에만 나오고 `devicectl` 이 그걸 스트리밍해 주지 않는다.
enum DebugFileLog {

    // MARK: - Constants

    private enum Constants {
        static let fileName = "umc-debug-events.log"
        /// 파일이 무한정 자라지 않게 자르는 기준. 넘으면 뒤쪽 절반만 남긴다.
        static let maxBytes = 512 * 1024
    }

    // MARK: - Static Property

    /// 쓰기 직렬화. 이벤트는 여러 스레드(전송 큐·메인)에서 들어온다.
    private static let queue = DispatchQueue(label: "dev.umc.debug.filelog")

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    static var fileURL: URL? {
        FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(Constants.fileName)
    }

    // MARK: - Static Function

    /// 한 줄 남긴다. 타임스탬프는 여기서 붙인다 — 호출부마다 다르면 정렬이 안 된다.
    static func append(_ line: String) {
        let stamped = "\(timestampFormatter.string(from: Date()))  \(line)\n"
        queue.async {
            guard let url = fileURL, let data = stamped.data(using: .utf8) else { return }

            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: url, options: .atomic)
            }
            truncateIfNeeded(at: url)
        }
    }

    /// 세션 경계를 남긴다. 이전 실행의 로그와 섞이면 어느 시도의 결과인지 못 가린다.
    static func markSessionStart(_ note: String) {
        append("──────── \(note) ────────")
    }

    private static func truncateIfNeeded(at url: URL) {
        guard let size = try? FileManager.default
            .attributesOfItem(atPath: url.path)[.size] as? Int,
              size > Constants.maxBytes,
              let contents = try? Data(contentsOf: url) else { return }

        let tail = contents.suffix(Constants.maxBytes / 2)
        try? tail.write(to: url, options: .atomic)
    }
}
#endif
