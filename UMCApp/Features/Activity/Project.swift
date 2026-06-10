import ProjectDescription
import ProjectDescriptionHelpers

let project = featureProject(
    name: "Activity",
    domainDestinations: [.iPhone, .appleWatch],
    domainDeploymentTargets: .multiplatform(iOS: "26.3", watchOS: "26.3"),
    presentationExtraDependencies: [
        .project(target: "BusinessCardPresentation", path: .relativeToRoot("Features/BusinessCard")),
    ],
    includesDomainTests: true,
    includesDataTests: true,
    dataTestDependencies: [
        .external(name: "Moya"),
    ]
)
