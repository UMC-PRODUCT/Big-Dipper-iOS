import ProjectDescription
import ProjectDescriptionHelpers

let project = featureProject(
    name: "MyPage",
    presentationExtraDependencies: [
        .project(target: "BusinessCardPresentation", path: .relativeToRoot("Features/BusinessCard")),
        .project(target: "BadgeDomain", path: .relativeToRoot("Features/Badge")),
    ]
)
