//
//  EditorToolbarViewModel+RangeHelpers.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import Foundation
import UIKit

extension EditorToolbarViewModel {

    // MARK: - Range Helpers

    func clampedSelectedRange(in storage: NSTextStorage) -> NSRange {
        let safeLocation = selectedRange.location == NSNotFound ? 0 : min(max(selectedRange.location, 0), storage.length)
        let requestedLength = selectedRange.length == NSNotFound ? 0 : max(selectedRange.length, 0)
        let safeLength = min(requestedLength, max(0, storage.length - safeLocation))
        return NSRange(location: safeLocation, length: safeLength)
    }

    func safeAttributeLocation(for range: NSRange, in storage: NSTextStorage) -> Int {
        guard storage.length > 0 else { return 0 }
        if range.location < storage.length {
            return range.location
        }
        return max(0, storage.length - 1)
    }

    func currentParagraphRange(in storage: NSTextStorage) -> NSRange {
        guard storage.length > 0 else {
            return NSRange(location: 0, length: 0)
        }

        let clampedRange = clampedSelectedRange(in: storage)
        let anchorLocation = min(clampedRange.location, storage.length)
        let nsString = storage.string as NSString
        return nsString.paragraphRange(for: NSRange(location: anchorLocation, length: 0))
    }

    func isAtEOFEmptyParagraph(in storage: NSTextStorage) -> Bool {
        let clampedRange = clampedSelectedRange(in: storage)
        return storage.length > 0
            && clampedRange.location >= storage.length
            && (storage.string as NSString).character(at: storage.length - 1) == 0x0A // \n
    }

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

    func syncRange(in storage: NSTextStorage) -> NSRange? {
        let clampedRange = clampedSelectedRange(in: storage)
        if clampedRange.length > 0 {
            return clampedRange
        }

        guard storage.length > 0 else { return nil }
        if clampedRange.location >= storage.length {
            return nil
        }
        return NSRange(location: clampedRange.location, length: 1)
    }

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
