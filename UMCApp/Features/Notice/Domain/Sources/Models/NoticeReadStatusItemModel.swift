//
//  NoticeReadStatusItemModel.swift
//  NoticeDomain
//
//  Created by 이예지 on 5/8/26.
//

import Foundation

/// 공지 확인 상태 모델
public struct NoticeReadStatusItemModel: Equatable, Identifiable {
    public let id = UUID()
    public let profileImageURL: String?
    public let userName: String
    public let nickName: String
    public let part: String
    public let location: String
    public let campus: String
    public let isRead: Bool

    public var identityText: String {
        let trimmedNickname = nickName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedNickname.isEmpty, !trimmedName.isEmpty, trimmedNickname != trimmedName {
            return "\(trimmedNickname)/\(trimmedName)"
        }
        return !trimmedNickname.isEmpty ? trimmedNickname : trimmedName
    }
}
