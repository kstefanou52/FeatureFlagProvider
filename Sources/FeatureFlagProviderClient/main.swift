import FeatureFlagProvider

#GenerateFeatureFlags(
    from: [
        "SEARCH_INDEXING": true,
        "ANALYTICS": false,
    ],
    enumName: "FeatureFlag",
    caseStyle: .camelCase
)

#GenerateFeatureFlagsView(enumName: "FeatureFlag")
