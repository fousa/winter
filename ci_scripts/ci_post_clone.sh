#!/bin/sh
# Xcode Cloud runs this right after cloning, before it looks for the project
# (ADR 0016). Winter.xcodeproj is generated from project.yml and is not in
# git, so it is generated here, the same way a contributor does after a clone.
set -eu

cd "$CI_PRIMARY_REPOSITORY_PATH"

# The bundle identifier and the team are personal, not part of the open-source
# repository (Config/Shared.xcconfig defaults to com.example). Xcode Cloud
# passes them in as environment variables set on the workflow.
if [ -n "${WINTER_BUNDLE_ID_PREFIX:-}" ]; then
    {
        echo "BUNDLE_ID_PREFIX = ${WINTER_BUNDLE_ID_PREFIX}"
        echo "DEVELOPMENT_TEAM = ${WINTER_DEVELOPMENT_TEAM:-}"
    } > Config/Local.xcconfig
    echo "Wrote Config/Local.xcconfig for ${WINTER_BUNDLE_ID_PREFIX}.winter"
else
    echo "warning: WINTER_BUNDLE_ID_PREFIX is not set; building as com.example.winter" >&2
fi

# Homebrew is preinstalled on Xcode Cloud. Skipping its self-update saves a
# minute per build.
HOMEBREW_NO_AUTO_UPDATE=1 brew install xcodegen
xcodegen generate
