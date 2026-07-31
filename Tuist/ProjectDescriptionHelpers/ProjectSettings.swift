import ProjectDescription

/// TODO: 팀 organization identifier 확정 후 교체 (설계 문서 §11-②)
public let bundleIdPrefix = "com.jeong.hannun"
public let hannunDestinations: Destinations = [.iPhone, .iPad]
public let hannunDeploymentTargets: DeploymentTargets = .iOS("26.0")

public extension SettingsDictionary {
    static var hannunBase: SettingsDictionary {
        [
            "SWIFT_VERSION": "6.0",
            "SWIFT_STRICT_CONCURRENCY": "complete",
            "SWIFT_UPCOMING_FEATURE_EXISTENTIAL_ANY": "YES",
            "SWIFT_TREAT_WARNINGS_AS_ERRORS": "YES",
        ]
    }
}
