import ProjectDescription
import ProjectDescriptionHelpers

let project = featureProject(
    name: "Community",
    domainExtraDependencies: [
        // 공지 링크 카드(#1142)의 메타를 NoticeDomain 의 공지 상세 조회에서 가져온다.
        .project(target: "NoticeDomain", path: .relativeToRoot("Features/Notice")),
    ],
    presentationExtraDependencies: [
        .project(target: "CoreDI", path: .relativeToRoot("Core/DI")),
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
        .project(target: "CoreRouting", path: .relativeToRoot("Core/Routing")),
        // 공지 링크 카드 탭이 상위로 넘기는 값이 `NoticeDomain.NoticeDetail` 이다.
        .project(target: "NoticeDomain", path: .relativeToRoot("Features/Notice")),
    ],
    includesDataTests: true,
    dataTestDependencies: [
        .target(name: "CommunityDomain"),
        .project(target: "CoreNetwork", path: .relativeToRoot("Core/Network")),
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
    ],
    includesPresentationTests: true,
    presentationTestDependencies: [
        .target(name: "CommunityDomain"),
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
    ]
)
