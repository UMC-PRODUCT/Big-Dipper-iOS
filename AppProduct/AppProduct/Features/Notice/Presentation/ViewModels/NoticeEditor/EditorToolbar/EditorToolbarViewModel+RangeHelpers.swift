//
//  EditorToolbarViewModel+RangeHelpers.swift
//  AppProduct
//
//  Created by euijjang97 on 4/8/26.
//

import Foundation
import UIKit

extension EditorToolbarViewModel {

    // MARK: - Range Helpers

    /// 유효한 선택 범위를 텍스트 스토리지 길이에 맞게 보정합니다.
    func clampedSelectedRange(in storage: NSTextStorage) -> NSRange {
        let safeLocation = selectedRange.location == NSNotFound ? 0 : min(max(selectedRange.location, 0), storage.length)
        let requestedLength = selectedRange.length == NSNotFound ? 0 : max(selectedRange.length, 0)
        let safeLength = min(requestedLength, max(0, storage.length - safeLocation))
        return NSRange(location: safeLocation, length: safeLength)
    }

    /// 속성 조회에 사용할 안전한 위치를 계산합니다.
    func safeAttributeLocation(for range: NSRange, in storage: NSTextStorage) -> Int {
        guard storage.length > 0 else { return 0 }
        if range.location < storage.length {
            return range.location
        }
        return max(0, storage.length - 1)
    }

    /// 현재 단락 범위를 계산합니다.
    /// EOF 빈 줄(커서가 storage.length에 있고 마지막 문자가 \n인 경우)도 올바르게 처리합니다.
    func currentParagraphRange(in storage: NSTextStorage) -> NSRange {
        guard storage.length > 0 else {
            return NSRange(location: 0, length: 0)
        }

        let clampedRange = clampedSelectedRange(in: storage)
        // NSString.paragraphRange는 location == length를 허용하므로
        // storage.length - 1로 clamp하지 않습니다.
        let anchorLocation = min(clampedRange.location, storage.length)
        let nsString = storage.string as NSString
        return nsString.paragraphRange(for: NSRange(location: anchorLocation, length: 0))
    }

    /// 커서가 EOF 빈 단락에 있는지 확인합니다.
    /// EOF 빈 단락에서는 storage attribute 대신 typingAttributes를 기준으로 처리해야 합니다.
    func isAtEOFEmptyParagraph(in storage: NSTextStorage) -> Bool {
        let clampedRange = clampedSelectedRange(in: storage)
        return storage.length > 0
            && clampedRange.location >= storage.length
            && (storage.string as NSString).character(at: storage.length - 1) == 0x0A // \n
    }

    /// 선택 범위가 걸친 전체 단락 범위를 계산합니다.
    func selectedParagraphRange(in storage: NSTextStorage) -> NSRange {
        guard storage.length > 0 else {
            return NSRange(location: 0, length: 0)
        }

        let clampedRange = clampedSelectedRange(in: storage)
        let nsString = storage.string as NSString
        if clampedRange.length > 0 {
            return nsString.paragraphRange(for: clampedRange)
        }

        let anchorLocation = min(clampedRange.location, storage.length)
        return nsString.paragraphRange(for: NSRange(location: anchorLocation, length: 0))
    }

    /// 단락 범위를 개별 단락 배열로 분해합니다.
    func paragraphRanges(in range: NSRange, storage: NSTextStorage) -> [NSRange] {
        guard storage.length > 0, range.length > 0 else { return [] }

        var ranges: [NSRange] = []
        let nsString = storage.string as NSString
        var currentLocation = range.location
        let upperBound = NSMaxRange(range)

        while currentLocation < upperBound {
            let paragraphRange = nsString.paragraphRange(for: NSRange(location: currentLocation, length: 0))
            ranges.append(paragraphRange)
            let next = NSMaxRange(paragraphRange)
            guard next > currentLocation else { break }
            currentLocation = next
        }

        return ranges
    }

    /// 동기화 시 사용할 실제 속성 조회 범위를 계산합니다.
    /// EOF 빈 단락에서는 nil을 반환하여 typingAttributes 기반 처리를 유도합니다.
    func syncRange(in storage: NSTextStorage) -> NSRange? {
        let clampedRange = clampedSelectedRange(in: storage)
        if clampedRange.length > 0 {
            return clampedRange
        }

        guard storage.length > 0 else { return nil }
        // EOF 빈 단락(커서가 storage.length에 있는 경우)은 nil 반환
        if clampedRange.location >= storage.length {
            return nil
        }
        return NSRange(location: clampedRange.location, length: 1)
    }

    /// 선택 치환 후 커서 위치와 길이를 보정합니다.
    func adjustSelectedRange(forReplacing range: NSRange, with replacementLength: Int) {
        let delta = replacementLength - range.length
        let selectionEnd = NSMaxRange(selectedRange)
        let replacedEnd = NSMaxRange(range)

        if selectedRange.location >= replacedEnd {
            selectedRange.location += delta
        } else if selectedRange.location > range.location {
            selectedRange.location = range.location + replacementLength
        }

        if selectionEnd >= replacedEnd {
            selectedRange.length = max(0, selectedRange.length + delta)
        } else if selectionEnd > range.location {
            selectedRange.length = max(0, range.location + replacementLength - selectedRange.location)
        }

        selectedRange.location = max(0, selectedRange.location)
    }
}
