import ProjectDescription
import ProjectDescriptionHelpers

let project = featureProject(
    name: "Community",
    presentationExtraDependencies: [
        .project(target: "BusinessCardPresentation", path: .relativeToRoot("Features/BusinessCard")),
    ]
)
