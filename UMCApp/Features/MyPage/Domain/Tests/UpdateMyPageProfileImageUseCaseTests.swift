//
//  UpdateMyPageProfileImageUseCaseTests.swift
//  MyPageDomainTests
//
//  Created by 김동민 on 7/4/26.
//

import Testing
import Foundation
@testable import MyPageDomain

@Suite("UpdateMyPageProfileImageUseCase — Repository 위임 검증")
struct UpdateMyPageProfileImageUseCaseTests {

    @Test("execute(imageData:fileName:contentType:) 호출 시 repository.updateProfileImage에 인자를 그대로 넘기고 결과를 반환한다")
    func delegatesToUpdateProfileImage() async throws {
        let imageData = Data("fake-image-bytes".utf8)
        let expected = makeStubProfileData(challengeId: 7)
        let mock = MockMyPageRepository()
        mock.updateProfileImageResult = .success(expected)
        let useCase = UpdateMyPageProfileImageUseCase(repository: mock)

        let result = try await useCase.execute(
            imageData: imageData,
            fileName: "profile.png",
            contentType: "image/png"
        )

        #expect(result == expected)
        #expect(mock.updateProfileImageCallCount == 1)
        #expect(mock.updateProfileImageReceivedImageData == imageData)
        #expect(mock.updateProfileImageReceivedFileName == "profile.png")
        #expect(mock.updateProfileImageReceivedContentType == "image/png")
    }

    @Test("repository가 에러를 던지면 그대로 전파한다")
    func propagatesError() async {
        let mock = MockMyPageRepository()
        mock.updateProfileImageResult = .failure(MyPageTestError.boom)
        let useCase = UpdateMyPageProfileImageUseCase(repository: mock)

        await #expect(throws: MyPageTestError.boom) {
            _ = try await useCase.execute(
                imageData: Data(),
                fileName: "x.png",
                contentType: "image/png"
            )
        }
    }
}
