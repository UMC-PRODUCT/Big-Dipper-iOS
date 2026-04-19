//
//  AITokenDailyUsageRecord.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import Foundation
import SwiftData

@Model
final class AITokenDailyUsageRecord {

    // MARK: - Property

    var memberId: Int = 0
    var date: Date = Date()
    var usedTokens: Int = 0

    // MARK: - Init

    init(
        memberId: Int,
        date: Date,
        usedTokens: Int
    ) {
        self.memberId = memberId
        self.date = date
        self.usedTokens = usedTokens
    }
}
