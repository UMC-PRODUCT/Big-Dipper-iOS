import ProjectDescription

let workspace = Workspace(
    name: "UMCApp",
    projects: [
        ".",
        "Core/*",
        "Features/*",
        "UMCAppWidget",
        "UMCWatchApp",
        "UMCWatchComplication",
    ]
)
