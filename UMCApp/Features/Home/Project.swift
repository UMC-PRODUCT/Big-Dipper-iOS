import ProjectDescription
import ProjectDescriptionHelpers

let project = featureProject(
    name: "Home",
    presentationExtraDependencies: [
        .project(target: "BusinessCardPresentation", path: .relativeToRoot("Features/BusinessCard")),
    ]
)
