//
//  Error+Cancellation.swift
//  AppProduct
//

import Foundation

extension Error {
    /// Swift Concurrency 취소(CancellationError) 또는
    /// URLSession 취소(-999 NSURLErrorCancelled) 여부를 반환합니다.
    ///
    /// .task modifier가 취소될 때 URLSession은 CancellationError를 전파합니다.
    /// 이 프로젝트의 NetworkClient는 URLSession을 직접 사용하므로
    /// 두 케이스 모두 CancellationError로 표면화됩니다.
    /// URLError(.cancelled) 체크는 하위 호환 및 방어적 처리를 위해 함께 포함합니다.
    var isCancellation: Bool {
        if self is CancellationError { return true }
        if let urlError = self as? URLError, urlError.code == .cancelled { return true }
        return false
    }
}
