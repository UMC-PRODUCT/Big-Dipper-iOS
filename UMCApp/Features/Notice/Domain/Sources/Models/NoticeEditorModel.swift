//
//  NoticeEditorModel.swift
//  NoticeDomain
//
//  Created by 이예지 on 5/8/26.
//

import Foundation
import UMCFoundation

// MARK: - NoticeTargetOption
/// 공지 타겟 선택(지부/학교)용 옵션 모델
public struct NoticeTargetOption: Identifiable, Equatable, Hashable {
    public let id: String
    public let name: String
    
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}



