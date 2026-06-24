import ProjectDescription
import ProjectDescriptionHelpers

let project = featureProject(
    name: "Notice",
    presentationExtraDependencies: [
        .project(target: "CoreDI", path:
                .relativeToRoot("Core/DI"))
    ])
