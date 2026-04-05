//
//  ActivityStudyTestView.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/30/26.
//

import SwiftUI

#if DEBUG
struct ActivityStudyTestView: View {
    var body: some View {
        ChallengerCurriculumView(
            curriculumModel: CurriculumProgressModel(
                partName: "iOS PART CURRICULUM",
                curriculumTitle: "Swift 기초 문법",
                completedCount: 2,
                totalCount: 8
            ),
            missions: MissionPreviewData.iosMissions
        )
    }
}

#Preview {
    ActivityStudyTestView()
}
#endif
