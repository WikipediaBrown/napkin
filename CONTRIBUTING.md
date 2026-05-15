# Contributing to napkin

Thanks for your interest in contributing! napkin is a small Swift framework
maintained by a solo developer, and outside help is genuinely appreciated.

For an introduction to the project, see the [README](README.md) and the full
[DocC reference and articles](https://wikipediabrown.github.io/napkin/documentation/napkin/).

## Reporting bugs

Open an issue using the [bug report template](.github/ISSUE_TEMPLATE/bug_report.yml).
The more reproduction detail you can provide — exact napkin version, Xcode
version, OS version, minimal repro — the faster a fix can land.

## Proposing changes

For small, well-scoped enhancements or bug fixes, feel free to send a PR directly.

For anything non-trivial — new public API, architectural change, large
refactor — please open a [feature request](.github/ISSUE_TEMPLATE/feature_request.yml)
or start a [Discussion](https://github.com/WikipediaBrown/napkin/discussions)
first. It's a lot easier to align on direction before you've written the code.

## Dev setup

```bash
git clone https://github.com/WikipediaBrown/napkin.git
cd napkin
swift build
swift test
```

You'll need Xcode 26 (Swift 6.2 toolchain) for the iOS 26 / macOS 26 SDKs.

## Running the example app

**Napkin's Rib House**, the reference app, lives in `Examples/RibHouse/`. The Xcode project is tracked in the repo, so just open it:

```bash
open Examples/RibHouse/RibHouse.xcodeproj
```

Hit ⌘R to run on a simulator. If you change `project.yml` or add files in new folders, regenerate the project with [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) and re-run `xcodegen` from `Examples/RibHouse/`.

## Running UI tests

The example app's UI tests drive a full login → logged-in → logout flow:

```bash
cd Examples/RibHouse
xcodebuild \
  -project RibHouse.xcodeproj \
  -scheme RibHouse \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  test
```

## Building docs locally

```bash
swift package \
  --allow-writing-to-directory ./docs \
  generate-documentation \
  --target napkin \
  --experimental-enable-custom-templates \
  --output-path ./docs
```

You can also use `swift package --disable-sandbox preview-documentation --target napkin`
for an auto-reloading local preview.

## Style

Follow existing patterns in `Sources/napkin/`. napkin enforces most of its
invariants through the type system and actor isolation — `swift build` and
`swift test` are the canonical style guide. If the compiler is happy and the
tests pass, you're probably in good shape.

## Commits

Commits should be signed:

```bash
git config commit.gpgsign true
```

Use clear, descriptive commit messages. Reference issues in the message body
where relevant.

## Pull requests

- Branch off `develop`, not `main`. `main` is reserved for the release pipeline.
- The PR template will prompt you for a summary, test plan, and related links.
- CI must be green before merge.
- Apply at least one `kind: *` label (`kind: bug`, `kind: enhancement`,
  `kind: docs`, etc.) so release notes categorize correctly.

## Releases

Releases are cut by the maintainer via the `Release` workflow. Merging to `main`
triggers a patch bump and tag; manual dispatch can request `minor` or `major`.
The `Documentation` workflow then runs after the release completes and deploys
the live site.
