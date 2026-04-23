import ProjectDescription
import ProjectDescriptionHelpers

let project = featureProject(
    name: "Auth",
    presentationExtraDependencies: [
        .project(target: "BusinessCardPresentation", path: .relativeToRoot("Features/BusinessCard")),
    ]
)
