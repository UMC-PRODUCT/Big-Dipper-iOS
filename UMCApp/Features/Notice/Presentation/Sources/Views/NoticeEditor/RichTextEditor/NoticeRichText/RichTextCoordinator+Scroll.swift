//
//  RichTextCoordinator+Scroll.swift
//  NoticePresentation
//
//  Created by 이예지 on 6/30/26.
//

import UIKit

extension RichTextCoordinator {

    // MARK: - Scroll

    /// 다음 run loop에서 커서 스크롤을 1회만 실행하도록 예약합니다.
    /// 빠른 입력/붙여넣기에서 예약이 누적되는 것을 방지합니다.
    func scheduleScrollCursorToVisible(in textView: UITextView) {
        pendingScrollWork?.cancel()
        let work = DispatchWorkItem { [weak self, weak textView] in
            guard let self, let textView else { return }
            self.scrollCursorToVisible(in: textView)
        }
        pendingScrollWork = work
        DispatchQueue.main.async(execute: work)
    }

    /// 프로그래매틱 텍스트 삽입 이후 커서가 화면에 보이도록 가장 가까운 UIScrollView를 스크롤합니다.
    ///
    /// isScrollEnabled = false인 UITextView는 자체 커서 추적을 하지 않으므로
    /// 부모 ScrollView를 직접 찾아 scrollRectToVisible을 호출합니다.
    func scrollCursorToVisible(in textView: UITextView) {
        guard let selectedRange = textView.selectedTextRange else { return }
        let cursorRect = textView.caretRect(for: selectedRange.end)
        guard !cursorRect.isNull, !cursorRect.isInfinite else { return }

        // 뷰 계층에서 첫 번째 수직 스크롤 가능한 UIScrollView를 탐색합니다.
        var ancestor: UIView? = textView.superview
        while let view = ancestor {
            if let scrollView = view as? UIScrollView,
               scrollView.isScrollEnabled,
               scrollView.contentSize.height > scrollView.bounds.height {
                let rectInScrollView = textView.convert(cursorRect, to: scrollView)
                let topInset = scrollView.adjustedContentInset.top
                let bottomInset = scrollView.adjustedContentInset.bottom
                let visibleMinY = scrollView.contentOffset.y + topInset
                let visibleMaxY = scrollView.contentOffset.y
                    + scrollView.bounds.height - bottomInset

                // 커서가 이미 visible rect 안에 있으면 스크롤 불필요
                if rectInScrollView.minY >= visibleMinY && rectInScrollView.maxY <= visibleMaxY {
                    return
                }

                var paddedRect = rectInScrollView.insetBy(
                    dx: 0,
                    dy: -Constants.cursorScrollPadding
                )
                if paddedRect.maxY > visibleMaxY {
                    paddedRect.size.height += bottomInset
                }
                scrollView.scrollRectToVisible(paddedRect, animated: false)
                return
            }
            ancestor = view.superview
        }
    }
}
