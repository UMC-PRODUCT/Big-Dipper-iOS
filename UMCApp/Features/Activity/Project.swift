import ProjectDescription
import ProjectDescriptionHelpers

let project = featureProject(
    name: "Activity",
    presentationExtraDependencies: [
        .project(target: "BusinessCardPresentation", path: .relativeToRoot("Features/BusinessCard")),
    ]
)
