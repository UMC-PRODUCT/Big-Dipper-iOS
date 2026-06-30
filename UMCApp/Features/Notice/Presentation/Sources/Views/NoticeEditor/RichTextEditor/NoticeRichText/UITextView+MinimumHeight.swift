//
//  UITextView+MinimumHeight.swift
//  NoticeData
//
//  Created by 이예지 on 6/30/26.
//

import UIKit

extension UITextView {

    var minimumHeight: CGFloat {
        let lineHeight = font?.lineHeight ?? UIFont.preferredFont(forTextStyle: .body).lineHeight
        return ceil(lineHeight + textContainerInset.top + textContainerInset.bottom)
    }
}
