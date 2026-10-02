# Heyllo Rebrand (macOS) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebrand the forked macOS notch-companion app from "Coucou"/"Mochi" to "Heyllo"/"Lexy" — replacing every proprietary name, character-drawing code path, sound, icon, and demo asset — while keeping the existing engineering (state machine, hooks, integrations) intact.

**Architecture:** Three independent Mochi-drawing implementations (`BotEngine.swift`, `GreetingCanvasView.swift`, `UploadCanvasView.swift`) are replaced by calls into one new shared module, `LexyGeometry.swift`, via an immutable `LexyFrame` snapshot so the renderer never reaches into any engine's internal state. All load-bearing runtime identifiers (Keychain service, two embedded Python-relay socket paths, six hook-detection predicates, an Antigravity config key, a `UserDefaults` key, a published wire field) are renamed in lockstep, not just user-visible strings. The Xcode project is regenerated from a renamed `project.yml` via XcodeGen — never hand-edited.

**Tech Stack:** Swift 6, SwiftUI (`Canvas`/`GraphicsContext`) + raw `CGContext`, XcodeGen, Python 3 (embedded hook relay scripts), bash (release/test scripts).

**Spec:** `docs/superpowers/specs/2026-10-02-heyllo-rebrand-design.md`

## Global Constraints

- No functional/behavioral changes outside what the spec calls for — this is a rebrand, not a refactor or feature pass.
- Windows/Linux (`windows/`) is untouched in every task.
- Release/App Store code signing and notarization are out of scope — every build-verification step in this plan targets the **Debug** configuration only.
- No backward-compatibility aliasing for the `coucou_agent` wire field, the Antigravity config key (on write), or the hook install directory — this is a fresh, independently-named fork, not an in-place upgrade. The one exception is `withoutAgyHooks()`, which must remove **both** the old and new Antigravity keys so a pre-existing install's orphaned entry actually gets cleaned up.
- `LICENSE`'s MIT copyright notice is never edited — that's a legal requirement, not a style choice.
- This codebase has no automated test target. Verification in every task is: the project builds (`xcodegen generate && xcodebuild build` for the Debug config), `grep` checks confirm exact renames, and (where noted) a manual smoke check. Don't invent a test target that doesn't exist.
- Every task ends with a commit. Follow the user's commit format: `<type>: <description>`, body optional, `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>` trailer.

## Review Focus

1. **The App Store relay's hardcoded socket path must track the new bundle ID exactly** (`~/Library/Containers/<bundle-id>/Data/nb.sock`) — a one-character mismatch here fails silently (the relay swallows connection errors by design), so Task 9's string must be checked character-by-character against the bundle ID set in Task 2.
2. **All six self-identifying hook-detection predicates must move together** (4 in `HookServer.swift`, 2 in `IslandViewContent.swift`) — missing even one means hook reinstall duplicates entries or uninstall silently does nothing. Task 9/10 must grep-verify all six, not just the ones in the file currently being edited.
3. **`IslandStateMachine`'s `.coucou` case is a Swift enum case, not a string** — Task 12 must use Xcode-aware renaming (or careful whole-word matching), because a naive text substitution of "coucou" would also need to touch every `.coucou` call site listed in the spec, and renaming it to `.heyllo` (instead of the spec's chosen `.greeting`) would reintroduce brand-name pollution into unrelated state-machine code.
4. **`LexyFrame` must carry everything the three call sites need without any of them reaching back into another file's private state** — Tasks 6–8 should each be checked for "did this file stop calling any of its own old private draw helpers," since a half-migrated call site (new LexyGeometry calls mixed with leftover old Mochi-shaped helpers) would silently keep drawing Mochi in parts of the frame.
5. **The Keychain service rename (Task 11) breaks every previously-saved API key** — this is expected per the spec's risk notes, but the task must not attempt a migration (none is specified), and the verification step should confirm the app still *runs* and lets a user save a *new* key under the new service identifier, not that old keys still work.

---

### Task 1: Delete proprietary demo media

**Files:**
- Delete: `docs/media/` (entire directory — `chat.png`, `claude-code.png`, `coucou.png`, `demo.gif`, `demo.mp4`, `dizzy.png`, `icon.png`, `stripe.png`, `upload.png`)
- Delete: `design/` (entire directory — `captures/` 34 files, `prototype/notch-buddy.html`, `animations/greeting-v2.html`, `animations/upload-sequence.html`, `.DS_Store`)
- Modify: `README.md:20,50,51,54,55` (remove the five `<img>` tags referencing `docs/media/*`)

**Interfaces:** None — this task has no dependents and nothing depends on it. Safe to do first.

- [ ] **Step 1: Delete the proprietary media directories**

```bash
git rm -r docs/media design
```

- [ ] **Step 2: Remove the now-broken image references in README.md**

Open `README.md` and remove these five lines entirely (don't replace with placeholder images — new Lexy screenshots are a later, separate task per the spec):

```
<img src="docs/media/demo.gif" width="760" alt="Coucou in action">
```
and the two `<table>` rows:
```
<tr>
<td><img src="docs/media/claude-code.png" alt="Claude Code session"></td>
<td><img src="docs/media/stripe.png" alt="Stripe payments"></td>
</tr>
<tr>
<td><img src="docs/media/chat.png" alt="Chat with Claude"></td>
<td><img src="docs/media/dizzy.png" alt="Too many hits"></td>
</tr>
```
Leave the surrounding `<div align="center">` and `<table>` tags in place if other content still uses them — if the table becomes empty, remove the empty `<table>` tags too.

- [ ] **Step 3: Verify no remaining references to deleted media**

Run: `grep -rn "docs/media\|design/captures\|design/prototype\|design/animations" . --include="*.md" --include="*.html"`
Expected: no output (excluding this plan file and the spec file, which may mention the paths descriptively — check manually if anything else matches).

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "chore: remove proprietary Coucou/Mochi demo media

docs/media/ and design/ contain screenshots and prototypes of the
original Mochi character, which is proprietary per LICENSE-ASSETS.md
and cannot ship in this fork.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 2: Rename project folder, Xcode targets, and bundle identifiers

**Files:**
- Delete: `NotchBuddy/NotchBuddy.xcodeproj/` (committed, stale — regenerated fresh below)
- Delete: `NotchBuddy/.DS_Store`
- Move: `NotchBuddy/` → `Heyllo/` (entire directory tree, via `git mv`)
- Modify: `Heyllo/project.yml` (full rewrite of identifiers)
- Rename: `Heyllo/Resources/Coucou.entitlements` → `Heyllo/Resources/Heyllo.entitlements`
- Rename: `Heyllo/Resources/CoucouAppStore.entitlements` → `Heyllo/Resources/HeylloAppStore.entitlements`
- Modify: `.gitignore` (update `NotchBuddy/` path references to `Heyllo/`)

**Interfaces:** None yet — this is pure structure/config. Every later task's file paths assume `Heyllo/` exists after this task.

- [ ] **Step 1: Move the project folder and delete the stale generated project**

```bash
git mv NotchBuddy Heyllo
git rm -r Heyllo/NotchBuddy.xcodeproj
rm -f Heyllo/.DS_Store
```

- [ ] **Step 2: Rename the entitlements files**

```bash
git mv Heyllo/Resources/Coucou.entitlements Heyllo/Resources/Heyllo.entitlements
git mv Heyllo/Resources/CoucouAppStore.entitlements Heyllo/Resources/HeylloAppStore.entitlements
```

- [ ] **Step 3: Rewrite `Heyllo/project.yml`**

Replace the entire file with:

```yaml
name: Heyllo
options:
  bundleIdPrefix: app.heyllo
  deploymentTarget:
    macOS: "15.0"
  xcodeVersion: "27.0"
  createIntermediateGroups: true

settings:
  base:
    SWIFT_VERSION: "6.0"
    ENABLE_HARDENED_RUNTIME: YES
    CODE_SIGN_STYLE: Manual
    OTHER_SWIFT_FLAGS: "-strict-concurrency=complete"
  configs:
    Debug:
      CODE_SIGNING_REQUIRED: NO
      CODE_SIGNING_ALLOWED: NO
    Release:
      CODE_SIGNING_REQUIRED: YES
      CODE_SIGNING_ALLOWED: YES
      CODE_SIGN_IDENTITY: "Developer ID Application"
      OTHER_CODE_SIGN_FLAGS: "--timestamp"
      CODE_SIGN_INJECT_BASE_ENTITLEMENTS: NO
      CODE_SIGN_ENTITLEMENTS: Resources/Heyllo.entitlements

schemes:
  Heyllo:
    build:
      targets:
        Heyllo: all
    run:
      config: Debug
    archive:
      config: Release
  HeylloAppStore:
    build:
      targets:
        HeylloAppStore: all
    run:
      config: Debug
    archive:
      config: Release

targets:
  Heyllo:
    type: application
    platform: macOS
    sources:
      - path: Sources
        type: group
      - path: Assets.xcassets
        buildPhase: resources
      - path: Resources/sounds
        buildPhase: resources
        type: folder
    info:
      path: Resources/Info.plist
      properties:
        CFBundleName: Heyllo
        CFBundleDisplayName: Heyllo
        CFBundleIdentifier: app.heyllo
        CFBundleVersion: "2"
        CFBundleShortVersionString: "0.1.1"
        CFBundlePackageType: APPL
        LSUIElement: YES
        NSHighResolutionCapable: YES
        NSSupportsAutomaticGraphicsSwitching: YES
        NSAppleEventsUsageDescription: "Pour sauter au terminal et envoyer des mails."
        NSAccessibilityUsageDescription: "Pour lire le titre de la fenêtre active et l'attacher comme contexte."
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: app.heyllo
        PRODUCT_NAME: Heyllo
        INFOPLIST_FILE: Resources/Info.plist
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        MACOSX_DEPLOYMENT_TARGET: "15.0"
        ENABLE_SANDBOX: NO

  HeylloAppStore:
    type: application
    platform: macOS
    sources:
      - path: Sources
        type: group
      - path: Assets.xcassets
        buildPhase: resources
      - path: Resources/sounds
        buildPhase: resources
        type: folder
    info:
      path: Resources/InfoAppStore.plist
      properties:
        CFBundleName: Heyllo
        CFBundleDisplayName: Heyllo
        CFBundleIdentifier: app.heyllo-appstore
        CFBundleVersion: "4"
        CFBundleShortVersionString: "1.0"
        CFBundlePackageType: APPL
        LSUIElement: YES
        NSHighResolutionCapable: YES
        NSSupportsAutomaticGraphicsSwitching: YES
        LSApplicationCategoryType: public.app-category.developer-tools
        ITSAppUsesNonExemptEncryption: NO
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: app.heyllo-appstore
        PRODUCT_NAME: Heyllo
        INFOPLIST_FILE: Resources/InfoAppStore.plist
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        MACOSX_DEPLOYMENT_TARGET: "15.0"
        CODE_SIGN_STYLE: Automatic
        CODE_SIGN_IDENTITY: "Apple Development"
        CODE_SIGN_ENTITLEMENTS: Resources/HeylloAppStore.entitlements
        SWIFT_ACTIVE_COMPILATION_CONDITIONS: APPSTORE
        CODE_SIGNING_ALLOWED: YES
```

Note what was deliberately removed versus the original: both `DEVELOPMENT_TEAM: 256AUJ9555` lines are gone (that team ID belongs to the original author; Release signing is out of scope per the spec, and Debug builds don't need a team ID at all). The App Store bundle ID is `app.heyllo-appstore` — a sibling of `app.heyllo`, not nested under it, per the spec's naming table.

- [ ] **Step 4: Record the exact App Store bundle ID for later tasks**

Write it down now — Task 9 needs this exact string for the embedded Python relay's container socket path: **`app.heyllo-appstore`**.

- [ ] **Step 5: Update `.gitignore`**

Open `.gitignore` and replace the three `NotchBuddy/` lines:

```
# Build artefacts
Heyllo/build/
Heyllo/Heyllo.xcodeproj/project.xcworkspace/xcuserdata/
Heyllo/Heyllo.xcodeproj/xcuserdata/
*.xcuserstate
```

(The rest of the file — macOS/.DS_Store/.icloud/.claude/ entries — is unchanged.)

- [ ] **Step 6: Regenerate the Xcode project and verify the Debug build**

```bash
cd Heyllo
xcodegen generate
xcodebuild -project Heyllo.xcodeproj -scheme Heyllo -configuration Debug build
cd ..
```

Expected: `xcodegen generate` succeeds and creates `Heyllo/Heyllo.xcodeproj/`; `xcodebuild` reports `** BUILD SUCCEEDED **`. (The build will still reference old Mochi-named Swift types at this point — that's expected, later tasks address those. If the build fails, it must fail only on missing-asset or identifier issues that later tasks fix, not on anything structural from this task — if it fails on a `project.yml` typo, fix it now before moving on.)

- [ ] **Step 7: Commit**

```bash
git add -A Heyllo .gitignore
git commit -m "refactor: rename project NotchBuddy -> Heyllo, Coucou -> Heyllo bundle IDs

- Folder NotchBuddy/ -> Heyllo/, Xcode targets NotchBuddy -> Heyllo and
  CoucouAppStore -> HeylloAppStore.
- Bundle IDs fr.louisraille.NotchBuddy -> app.heyllo and
  fr.louisraille.Coucou -> app.heyllo-appstore (sibling, not nested).
- Entitlements files renamed to match. DEVELOPMENT_TEAM (original
  author's) removed; Release signing is deferred until the fork has its
  own Apple Developer Team ID.
- Deleted the stale committed .xcodeproj; it's regenerated by xcodegen.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: Rename the app entry point

**Files:**
- Rename: `Heyllo/Sources/App/NotchBuddyApp.swift` → `Heyllo/Sources/App/HeylloApp.swift`

**Interfaces:**
- Produces: `struct HeylloApp: App` (replaces `struct NotchBuddyApp: App`) — the `@main` entry point every other file's app lifecycle assumes exists, unchanged in behavior.

- [ ] **Step 1: Rename the file and the type**

```bash
git mv Heyllo/Sources/App/NotchBuddyApp.swift Heyllo/Sources/App/HeylloApp.swift
```

Open `Heyllo/Sources/App/HeylloApp.swift` and change:
```swift
struct NotchBuddyApp: App {
```
to:
```swift
struct HeylloApp: App {
```

- [ ] **Step 2: Verify no other file references the old type name**

Run: `grep -rn "NotchBuddyApp" Heyllo/`
Expected: no output.

- [ ] **Step 3: Regenerate and build**

```bash
cd Heyllo && xcodegen generate && xcodebuild -project Heyllo.xcodeproj -scheme Heyllo -configuration Debug build && cd ..
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Heyllo
git commit -m "refactor: rename NotchBuddyApp -> HeylloApp

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 4: Extract shared drawing math into `DrawMath.swift`

**Files:**
- Create: `Heyllo/Sources/App/DrawMath.swift`
- Modify: `Heyllo/Sources/App/BotEngine.swift` (remove the extracted `private func`s, keep call sites working via the new file)

**Interfaces:**
- Produces: `lerp(_:_:_:)`, `clamp(_:_:_:)`, `cgColorToTuple(_:)`, `mix3(_:_:_:)`, `colorFromTuple(_:)`, `heartShape(size:)`, `starShape(size:points:)` — all non-`private` at file scope in the new `DrawMath.swift`, so `BotEngine.swift`, and later `LexyGeometry.swift` (Task 5), `GreetingCanvasView.swift` (Task 7), and `UploadCanvasView.swift` (Task 8) can all call them.
- Consumes: nothing new — these are pure functions moved as-is from `BotEngine.swift`.

This task is a pure move: find each of these `private func`s in `BotEngine.swift` (they're file-scope helpers, roughly in the 1419–1490 line range before Task 2's git history — use `grep -n "private func lerp\|private func clamp\|private func cgColorToTuple\|private func mix3\|private func colorFromTuple\|private func heartShape\|private func starShape" Heyllo/Sources/App/BotEngine.swift` to find their current exact locations after the Task 2 rename) and move them verbatim into the new file, dropping the `private` keyword so other files can use them.

- [ ] **Step 1: Locate the exact functions to move**

```bash
grep -n "^private func lerp\|^private func clamp\|^private func cgColorToTuple\|^private func mix3\|^private func colorFromTuple\|^private func heartShape\|^private func starShape" Heyllo/Sources/App/BotEngine.swift
```

Read each matched function's full body in `BotEngine.swift` before moving it — do not guess their implementation from the names alone, since `cgColorToTuple`/`mix3`/`colorFromTuple` encode this project's specific RGB-tuple convention used throughout the gradient-fill code.

- [ ] **Step 2: Create `Heyllo/Sources/App/DrawMath.swift`**

```swift
import Foundation
import CoreGraphics

// Shared drawing math and color helpers, used by BotEngine, LexyGeometry,
// GreetingCanvasView, and UploadCanvasView. Moved out of BotEngine.swift so
// it isn't the only file allowed to use them.
```

Then paste each function moved from `BotEngine.swift` in Step 1 below that header comment, with `private` removed from each `func` declaration (keep everything else — parameter names, bodies, types — identical to what you read in Step 1).

- [ ] **Step 3: Remove the moved functions from `BotEngine.swift`**

Delete each function body you just moved from `BotEngine.swift`. Leave every call site in `BotEngine.swift` unchanged — Swift resolves them against the new file-scope (non-private) declarations in `DrawMath.swift` automatically since both files are in the same target.

- [ ] **Step 4: Regenerate and build**

```bash
cd Heyllo && xcodegen generate && xcodebuild -project Heyllo.xcodeproj -scheme Heyllo -configuration Debug build && cd ..
```
Expected: `** BUILD SUCCEEDED **`. If it fails with "cannot find X in scope," you missed a call site or a function signature doesn't match what you pasted — compare against what you read in Step 1.

- [ ] **Step 5: Commit**

```bash
git add Heyllo
git commit -m "refactor: extract shared drawing math into DrawMath.swift

lerp/clamp/cgColorToTuple/mix3/colorFromTuple/heartShape/starShape were
private to BotEngine.swift, so no other file could reuse them. Moving
them out (and de-privatizing) lets the upcoming LexyGeometry module and
GreetingCanvasView/UploadCanvasView share one implementation instead of
three copies.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 5: Create `LexyGeometry.swift` — the shared character renderer

**Files:**
- Create: `Heyllo/Sources/App/LexyGeometry.swift`

**Interfaces:**
- Consumes: `lerp`, `clamp`, `cgColorToTuple`, `mix3`, `colorFromTuple` from `DrawMath.swift` (Task 4).
- Produces (all used by Tasks 6–8):
  - `enum EyeShape: String { case pill, wide, dot, line, flat, happy, closed, spiral, heart, star, tired, wink, cup }` (moved here from `BotEngine.swift`)
  - `enum LexyConst` with `eyeW`, `eyeH`, `eyeSp`, `eyeP`, `baseTop`, `baseBottom`, `ink`, `miniInk` (renamed from `MochiConst`, same values) plus `bowtieColor`
  - `struct LexyFrame` — the immutable per-draw-call snapshot (fields below)
  - `func lexyFacePath(rx: CGFloat, ry: CGFloat, morph: CGFloat) -> CGPath` — dot-cluster face silhouette as a single path (union of the face dots), used for clipping/fills
  - `func drawLexyFace(cg: CGContext, frame: LexyFrame)` — draws body + eyes + bowtie, given a `LexyFrame` already positioned/scaled by the caller (callers `saveGState`/`translateBy`/`scaleBy` before calling this; this function draws in local body-centered coordinates, matching how `BotEngine.mochiPath` and `GreetingCanvasView.mochiPath` already work)
  - `func drawLexyHands(cg: CGContext, frame: LexyFrame, rx: CGFloat, ry: CGFloat)` — dot-cluster hand shapes

**Design notes for the implementer:** All three call sites (`BotEngine` via SwiftUI `GraphicsContext`, `GreetingCanvasView` via raw `CGContext`, `UploadCanvasView` via SwiftUI `GraphicsContext`) need one shared implementation. `GraphicsContext` provides `withCGContext { cg in ... }` (already used elsewhere in this codebase, e.g. `UploadCanvasView.swift:436`), so standardizing `LexyGeometry`'s public functions on raw `CGContext` lets every call site reach it — `GreetingCanvasView` calls it directly (it already works in `CGContext`), `BotEngine`/`UploadCanvasView` wrap the call in `ctx.withCGContext { cg in ... }`.

- [ ] **Step 1: Find and read the exact `EyeShape` and `MochiConst` declarations to move**

```bash
grep -n "^enum EyeShape\|^enum MochiConst" -A 10 Heyllo/Sources/App/BotEngine.swift
```

- [ ] **Step 2: Create `Heyllo/Sources/App/LexyGeometry.swift`**

```swift
import Foundation
import CoreGraphics
import SwiftUI

// MARK: - Eye shape vocabulary (moved from BotEngine.swift — shared renderer vocabulary,
// also consumed by IslandTypes.swift's `miniEye`)

enum EyeShape: String {
    case pill, wide, dot, line, flat, happy, closed, spiral, heart, star, tired, wink, cup
}

// MARK: - Lexy tunable constants (renamed from MochiConst, same values)

enum LexyConst {
    static let eyeW: CGFloat  = 0.25
    static let eyeH: CGFloat  = 0.27
    static let eyeSp: CGFloat = 0.37
    static let eyeP: CGFloat  = -0.12
    static let baseTop    = CGColor(red: 0.929, green: 0.929, blue: 0.937, alpha: 1)  // #EDEDEF
    static let baseBottom = CGColor(red: 0.769, green: 0.773, blue: 0.792, alpha: 1)  // #C4C5CA
    static let ink        = CGColor(red: 0.102, green: 0.082, blue: 0.071, alpha: 1)  // #1A1412
    static let miniInk    = CGColor(red: 0.063, green: 0.075, blue: 0.102, alpha: 1)  // #10131A
    // Lexy's signature accessory: a small dark navy bowtie, the one "lawyer but cute" cue.
    static let bowtieColor = CGColor(red: 0.11, green: 0.12, blue: 0.16, alpha: 1)
}

// MARK: - LexyFrame: the one snapshot type every call site builds and LexyGeometry consumes.
// No function below reaches back into BotEngine, GreetPose, or USFrame — everything it needs
// to draw one frame is in this struct.

struct LexyFrame {
    var rx: CGFloat               // body half-width (world units, already scaled by caller)
    var ry: CGFloat               // body half-height
    var morph: CGFloat            // 0 = round dot-cluster face, 1 = compact box (upload mode)
    var eye: EyeShape
    var eyeOpen: CGFloat          // 0 = fully closed (blink), 1 = fully open
    var lookX: CGFloat            // -1...1, eye-cluster offset (pupil/gaze direction)
    var lookY: CGFloat
    var tint: CGFloat             // 0...1 color wash strength (state color, e.g. "thinking" purple)
    var tintColor: CGColor?       // nil = no tint
    var bodyColor: CGColor?       // nil = default LexyConst.baseTop/baseBottom gradient
    var blush: CGFloat            // 0...1
    var showBowtie: Bool          // hidden while morphing into box mode, like the body's extras
    var handsAmount: CGFloat      // 0...1, how present the hands are (0 = none drawn)
}

// MARK: - Dot-cluster face geometry

/// The face silhouette is a loose ring of overlapping dots whose union reads as one rounded
/// face, interpolated (via `morph`) toward a tighter rectangular dot grid for "box mode"
/// (the upload/mailbox animation). Returns one CGPath that is the union of all face dots —
/// used both to fill the body and to clip the eyes/bowtie to the face.
func lexyFacePath(rx: CGFloat, ry: CGFloat, morph: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let dotRadius = min(rx, ry) * 0.30
    let roundPositions = lexyRingDotPositions(rx: rx * 0.78, ry: ry * 0.78, count: 10)
    let boxPositions = lexyGridDotPositions(rx: rx * 0.86, ry: ry * 0.86, cols: 5, rows: 3)
    let count = min(roundPositions.count, boxPositions.count)
    for i in 0..<count {
        let p0 = roundPositions[i % roundPositions.count]
        let p1 = boxPositions[i % boxPositions.count]
        let x = lerp(p0.x, p1.x, morph)
        let y = lerp(p0.y, p1.y, morph)
        let r = dotRadius * lerp(1.0, 0.82, morph)
        path.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }
    return path
}

private func lexyRingDotPositions(rx: CGFloat, ry: CGFloat, count: Int) -> [CGPoint] {
    (0..<count).map { i in
        let a = (CGFloat(i) / CGFloat(count)) * .pi * 2
        return CGPoint(x: cos(a) * rx, y: sin(a) * ry)
    }
}

private func lexyGridDotPositions(rx: CGFloat, ry: CGFloat, cols: Int, rows: Int) -> [CGPoint] {
    var points: [CGPoint] = []
    for row in 0..<rows {
        for col in 0..<cols {
            let fx = cols == 1 ? 0 : CGFloat(col) / CGFloat(cols - 1) * 2 - 1
            let fy = rows == 1 ? 0 : CGFloat(row) / CGFloat(rows - 1) * 2 - 1
            points.append(CGPoint(x: fx * rx, y: fy * ry))
        }
    }
    return points
}

// MARK: - Eyes: each EyeShape maps to a small dot arrangement, not a single pupil

private func lexyEyeDotOffsets(for shape: EyeShape) -> [CGPoint] {
    switch shape {
    case .pill, .wide, .flat:
        return [CGPoint(x: -0.05, y: 0), CGPoint(x: 0.05, y: 0)]   // two dots, side by side
    case .dot, .line, .closed, .tired:
        return [CGPoint(x: 0, y: 0)]                                // single dot
    case .happy, .wink:
        return [CGPoint(x: -0.04, y: -0.02), CGPoint(x: 0.04, y: -0.02)]
    case .spiral, .star, .heart:
        return [CGPoint(x: -0.05, y: 0), CGPoint(x: 0, y: -0.04), CGPoint(x: 0.05, y: 0)]
    case .cup:
        return [CGPoint(x: -0.05, y: 0.03), CGPoint(x: 0.05, y: 0.03)]
    }
}

/// Draws the two eye-dot-clusters, clipped to the face path, offset by lookX/lookY.
private func drawLexyEyes(cg: CGContext, frame: LexyFrame, rx: CGFloat, ry: CGFloat) {
    let eyeDotR = min(rx, ry) * LexyConst.eyeH * 0.22 * max(0.15, frame.eyeOpen)
    let sp = ry * LexyConst.eyeSp
    let baseY = ry * LexyConst.eyeP + frame.lookY * ry * 0.18
    let lookOffsetX = frame.lookX * rx * 0.12

    for side: CGFloat in [-1, 1] {
        let centerX = side * sp + lookOffsetX
        let offsets = lexyEyeDotOffsets(for: frame.eye)
        for offset in offsets {
            let x = centerX + offset.x * rx
            let y = baseY + offset.y * ry
            cg.setFillColor(frame.bodyColor != nil ? LexyConst.ink : LexyConst.ink)
            cg.fillEllipse(in: CGRect(x: x - eyeDotR, y: y - eyeDotR, width: eyeDotR * 2, height: eyeDotR * 2))
        }
    }
}

/// Lexy's signature bowtie: two small triangular dots either side of a center dot, drawn
/// beneath the face. Hidden while morphing into box mode, same as the rest of the "extras."
private func drawLexyBowtie(cg: CGContext, frame: LexyFrame, rx: CGFloat, ry: CGFloat) {
    guard frame.showBowtie, frame.morph < 0.5 else { return }
    let alpha = 1 - frame.morph * 2
    let bowY = ry * 0.62
    let wingR = min(rx, ry) * 0.10
    let centerR = wingR * 0.55

    cg.saveGState()
    cg.setAlpha(alpha)
    cg.setFillColor(LexyConst.bowtieColor)
    cg.fillEllipse(in: CGRect(x: -wingR * 1.6 - wingR, y: bowY - wingR, width: wingR * 2, height: wingR * 2))
    cg.fillEllipse(in: CGRect(x: wingR * 1.6 - wingR, y: bowY - wingR, width: wingR * 2, height: wingR * 2))
    cg.fillEllipse(in: CGRect(x: -centerR, y: bowY - centerR, width: centerR * 2, height: centerR * 2))
    cg.restoreGState()
}

// MARK: - Public entry point

/// Draws one frame of Lexy: body (dot cluster), tint wash, eyes, bowtie. Callers are
/// responsible for translating/rotating/scaling `cg` to the character's world position before
/// calling this — this function draws entirely in body-centered local coordinates, matching
/// how the original BotEngine.mochiPath/GreetingCanvasView.mochiPath callers already work.
func drawLexyFace(cg: CGContext, frame: LexyFrame) {
    let facePath = lexyFacePath(rx: frame.rx, ry: frame.ry, morph: frame.morph)

    cg.saveGState()
    cg.addPath(facePath)
    cg.clip()

    let topColor = frame.bodyColor ?? LexyConst.baseTop
    let bottomColor = frame.bodyColor != nil ? mixDarker(frame.bodyColor!) : LexyConst.baseBottom
    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [topColor, bottomColor] as CFArray,
                                  locations: [0, 1]) {
        cg.drawLinearGradient(gradient,
                               start: CGPoint(x: 0, y: -frame.ry),
                               end: CGPoint(x: 0, y: frame.ry),
                               options: [])
    }

    if frame.tint > 0, let tintColor = frame.tintColor {
        cg.setFillColor(tintColor.copy(alpha: frame.tint) ?? tintColor)
        cg.addPath(facePath)
        cg.fillPath()
    }

    if frame.blush > 0.01 {
        cg.setFillColor(CGColor(red: 1, green: 0.55, blue: 0.55, alpha: Double(frame.blush) * 0.35))
        let blushR = frame.rx * 0.12
        for side: CGFloat in [-1, 1] {
            let x = side * frame.rx * 0.55
            let y = frame.ry * 0.25
            cg.fillEllipse(in: CGRect(x: x - blushR, y: y - blushR, width: blushR * 2, height: blushR * 2))
        }
    }
    cg.restoreGState()

    drawLexyEyes(cg: cg, frame: frame, rx: frame.rx, ry: frame.ry)
    drawLexyBowtie(cg: cg, frame: frame, rx: frame.rx, ry: frame.ry)
}

private func mixDarker(_ color: CGColor) -> CGColor {
    let t = cgColorToTuple(color)
    let darker = mix3(t, (0, 0, 0), 0.18)
    return colorFromTuple(darker)
}

// MARK: - Hands (dot-cluster form, replaces BotEngine's ellipse hands and
// GreetingCanvasView's drawHandL/drawHandR)

func drawLexyHands(cg: CGContext, frame: LexyFrame, rx: CGFloat, ry: CGFloat) {
    guard frame.handsAmount > 0.01 else { return }
    let handR = min(rx, ry) * 0.16 * frame.handsAmount
    for side: CGFloat in [-1, 1] {
        let x = side * rx * 1.08
        let y = ry * 0.70
        cg.setFillColor((frame.bodyColor ?? LexyConst.baseTop))
        cg.fillEllipse(in: CGRect(x: x - handR, y: y - handR, width: handR * 2, height: handR * 2))
        cg.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.08))
        cg.setLineWidth(1)
        cg.strokeEllipse(in: CGRect(x: x - handR, y: y - handR, width: handR * 2, height: handR * 2))
    }
}
```

This is a first visual pass, not a final design — the spec's risk notes explicitly call out that getting the dot-cluster proportions and bowtie placement right across all `EyeShape` states takes a few iterations. Treat the shapes/positions above as a working starting point that compiles and renders *something* recognizable, to be refined visually once the app builds and runs (Task 6 onward makes it buildable; iterate on this file afterward as needed).

- [ ] **Step 3: Verify the file compiles on its own by building the target**

```bash
cd Heyllo && xcodegen generate && xcodebuild -project Heyllo.xcodeproj -scheme Heyllo -configuration Debug build && cd ..
```
Expected: builds — `LexyGeometry.swift` isn't called by anything yet, so this just confirms it type-checks. `EyeShape`/`MochiConst` now exist in two places (old in `BotEngine.swift`, new in `LexyGeometry.swift`) — expect a "invalid redeclaration" build error at this step. That's expected and is resolved in Task 6 by deleting the old declarations; don't delete them yet in this task, since Task 6 needs to diff against the old code first.

Actually — to keep each task's build green, delete the old `EyeShape` and `MochiConst` declarations from `BotEngine.swift` now (in this task), replacing every `MochiConst.` reference in `BotEngine.swift` with `LexyConst.` as a mechanical find-replace (the two enums have identical members). Leave `BotEngine.swift`'s own drawing functions (`mochiPath`, `drawBody`, `drawEyes`, etc.) untouched for now — they still compile, they're just not yet calling into `LexyGeometry`. That wiring is Task 6.

```bash
grep -n "MochiConst\." Heyllo/Sources/App/BotEngine.swift
```
Replace each occurrence's `MochiConst` with `LexyConst`. Delete the `enum EyeShape` and `enum MochiConst` blocks from `BotEngine.swift` (now defined in `LexyGeometry.swift` instead).

- [ ] **Step 4: Rebuild and confirm no redeclaration errors**

```bash
cd Heyllo && xcodegen generate && xcodebuild -project Heyllo.xcodeproj -scheme Heyllo -configuration Debug build && cd ..
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Heyllo
git commit -m "feat: add LexyGeometry shared character renderer

New LexyGeometry.swift owns Lexy's dot-cluster face, eye-dot mapping,
bowtie, and hand geometry behind a LexyFrame snapshot type, so no
caller needs to read another file's internal state. EyeShape and
MochiConst (renamed LexyConst) move here from BotEngine.swift, which
is not yet wired to call the new renderer — that's the next task.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 6: Wire `LexyGeometry` into `BotEngine.swift`

**Files:**
- Modify: `Heyllo/Sources/App/BotEngine.swift` (replace `mochiPath`/`drawBody`/`drawEyes`/`drawEyeShape`/`drawHandsBehind`/`drawHandsAndExtras`'s hand-drawing with calls into `LexyGeometry`)

**Interfaces:**
- Consumes: `LexyFrame`, `drawLexyFace(cg:frame:)`, `drawLexyHands(cg:frame:rx:ry:)` from `LexyGeometry.swift` (Task 5).
- Produces: `BotEngine.draw(context:size:)` and `BotEngine.drawHandsBehind(context:size:)` keep their existing external signatures — nothing outside `BotEngine.swift` needs to change because of this task.

- [ ] **Step 1: Read the current `draw(context:size:)` body before editing**

```bash
grep -n "func draw(context" -A 80 Heyllo/Sources/App/BotEngine.swift
```
Confirm the exact current line range (it moved slightly after Task 4/5's edits) before replacing it.

- [ ] **Step 2: Replace the body-drawing portion of `draw(context:size:)`**

Keep the existing transform setup (the `W`/`H`/`R`/`rx`/`ry`/`cx`/`cy`/translate/rotate/scale block) exactly as-is — that positioning logic is state-machine/layout concern, not character geometry, and stays in `BotEngine`. Replace the body/eyes drawing calls (`mochiPath`, `drawBody`, `drawBlush`, `drawEyes`, and the mouth-hole block) with:

```swift
        // Resolve the active eye shape here (state-machine policy), then hand a pure
        // snapshot to LexyGeometry — it never reads BotEngine's own properties directly.
        let activeEye: EyeShape = {
            if morph > 0.2 {
                if isChewing { return .happy }
                if slotHTarget > 0.05 || slotH > 0.10 { return .cup }
            }
            return eyeOverride ?? cfg.eye
        }()

        let frame = LexyFrame(
            rx: rx, ry: ry, morph: morph,
            eye: activeEye, eyeOpen: open,
            lookX: cfg.look?.x ?? 0, lookY: cfg.look?.y ?? 0,
            tint: tint, tintColor: cfg.color,
            bodyColor: bodyColor,
            blush: max(blush, tint * 0.5) * (1 - morph),
            showBowtie: !isMini,
            handsAmount: hands
        )

        ctx.withCGContext { cg in
            drawLexyFace(cg: cg, frame: frame)
        }

        // Mouth hole — dark pill cutout inside the box face (upload/mailbox mode only)
```

Leave the existing mouth-hole block (the `if morph > 0.05 { ... }` block, starting with `let hW = R * 1.80 * morph`) exactly as it was — it draws on top of the face and isn't part of the Mochi-specific body/eye geometry; it's generic "box mode" chrome that still applies to Lexy's box form.

Delete the file's old `private func mochiPath`, `private func drawBody`, `private func drawBlush`, `private func drawEyes`, `private func drawEyeShape` — they're replaced by `LexyGeometry`'s equivalents. Keep `private func rrPoint` only if the mouth-hole block you kept still calls it; check with `grep -n "rrPoint" Heyllo/Sources/App/BotEngine.swift` before deleting.

- [ ] **Step 3: Replace `drawHandsBehind`'s hand-drawing with `drawLexyHands`**

Read the current function (`grep -n "func drawHandsBehind" -A 100 Heyllo/Sources/App/BotEngine.swift`). Keep the existing wave-pose/position calculation logic (the `isWaving`/`localX`/`localY`/`handRot`/`worldX`/`worldY` block) exactly as-is — that's animation/behavior, not geometry. Replace only the final drawing block (the part that builds `handPath` and fills it with the body-color gradient) with:

```swift
            var handCtx = context
            handCtx.translateBy(x: worldX, y: worldY)
            if handRot != 0 { handCtx.rotate(by: .radians(handRot)) }
            let frame = LexyFrame(
                rx: rx, ry: ry, morph: 0, eye: .pill, eyeOpen: 1,
                lookX: 0, lookY: 0, tint: 0, tintColor: nil,
                bodyColor: bodyColor, blush: 0, showBowtie: false,
                handsAmount: hands
            )
            handCtx.withCGContext { cg in
                drawLexyHands(cg: cg, frame: frame, rx: hew, ry: heh)
            }
```

(`hew`/`heh` are the function's existing hand half-width/half-height locals — keep using them.)

- [ ] **Step 4: Verify no leftover calls to deleted functions**

```bash
grep -n "mochiPath\|drawBody(\|drawBlush(\|drawEyes(\|drawEyeShape(" Heyllo/Sources/App/BotEngine.swift
```
Expected: no output (all calls removed along with the function definitions).

- [ ] **Step 5: Regenerate and build**

```bash
cd Heyllo && xcodegen generate && xcodebuild -project Heyllo.xcodeproj -scheme Heyllo -configuration Debug build && cd ..
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add Heyllo
git commit -m "refactor: wire BotEngine to draw Lexy via LexyGeometry

BotEngine keeps its state machine (timing, emotes, the logic deciding
which EyeShape to show) untouched. draw(context:size:) now resolves
that EyeShape and builds a LexyFrame snapshot, then delegates all body/
eye/hand geometry to LexyGeometry instead of its own mochiPath/
drawBody/drawEyes/drawEyeShape.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 7: Wire `LexyGeometry` into `GreetingCanvasView.swift`

**Files:**
- Modify: `Heyllo/Sources/App/GreetingCanvasView.swift` (replace `mochiPath`, `drawMochi`'s body/eye drawing, `drawHandL`/`drawHandR` with `LexyGeometry` calls)

**Interfaces:**
- Consumes: `LexyFrame`, `drawLexyFace(cg:frame:)`, `drawLexyHands(cg:frame:rx:ry:)` from `LexyGeometry.swift` (Task 5).
- Produces: `drawMochi(_:p:)`'s external call sites in this file are unchanged — only its internals change.

- [ ] **Step 1: Read the current `drawMochi`, `drawHandL`, `drawHandR`, and `mochiPath` functions**

```bash
grep -n "private func mochiPath(hw\|private func drawHandL\|private func drawHandR\|private func drawMochi" -A 5 Heyllo/Sources/App/GreetingCanvasView.swift
```

- [ ] **Step 2: Map `GEyeType` to `EyeShape` and replace the body/hands/eyes block in `drawMochi`**

Inside `drawMochi(_ ctx: CGContext, p: GreetPose)`, after the existing halo-drawing block (keep that — it's generic glow chrome, not character-specific) and the existing `ctx.saveGState(); ctx.translateBy(...); ctx.rotate(...); ctx.scaleBy(...)` transform setup (keep that too — it's positioning, not geometry), replace the hands/body/tint/eyes block (`drawHandL`, `drawHandR`, the `mochiPath`/`whiteFill` body fill, the tint overlay, and the per-eye `for sd: CGFloat in [-1, 1]` loop) with:

```swift
    let eyeShape: EyeShape = {
        switch p.eye {
        case .happy: return .happy
        case .content: return .cup
        case .dot: return .pill
        }
    }()

    let frame = LexyFrame(
        rx: hw, ry: hh, morph: 0,
        eye: eyeShape, eyeOpen: CGFloat(p.open),
        lookX: CGFloat(p.lookX), lookY: CGFloat(p.lookY) + CGFloat(p.eyeRoll) * 2,
        tint: CGFloat(p.tint),
        tintColor: CGColor(red: 127/255, green: 180/255, blue: 234/255, alpha: 1),
        bodyColor: nil, blush: 0,
        showBowtie: true,
        handsAmount: CGFloat(max(p.handL, p.handR))
    )
    drawLexyHands(cg: ctx, frame: frame, rx: hw, ry: hh)
    drawLexyFace(cg: ctx, frame: frame)
```

Keep the existing "Activity badge" block (`if p.badge > 0.01 { ... }`) unchanged below this — badges are generic chrome, not Mochi-specific geometry, same as in `BotEngine`.

Delete the now-unused `private func mochiPath(hw:hh:)`, `private func drawHandL`, `private func drawHandR` definitions from this file. Also check `private func whiteFill` — it may still be used elsewhere in the file (e.g., by a card or UI background draw); only delete it if `grep -n "whiteFill(" Heyllo/Sources/App/GreetingCanvasView.swift` shows no remaining call sites after your edit.

- [ ] **Step 3: Verify no leftover references**

```bash
grep -n "mochiPath(hw\|drawHandL(\|drawHandR(" Heyllo/Sources/App/GreetingCanvasView.swift
```
Expected: no output.

- [ ] **Step 4: Regenerate and build**

```bash
cd Heyllo && xcodegen generate && xcodebuild -project Heyllo.xcodeproj -scheme Heyllo -configuration Debug build && cd ..
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Heyllo
git commit -m "refactor: wire GreetingCanvasView to draw Lexy via LexyGeometry

The launch greeting had its own complete, independent Mochi
implementation (separate mochiPath exponent, drawHandL/drawHandR, eye
drawing). It now builds a LexyFrame from its GreetPose state and
delegates to the same LexyGeometry used by the main island pill, so
the greeting animation shows Lexy instead of Mochi.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 8: Wire `LexyGeometry` into `UploadCanvasView.swift`

**Files:**
- Modify: `Heyllo/Sources/App/UploadCanvasView.swift` (replace `drawEyeShape` and the body-drawing portion with `LexyGeometry` calls)

**Interfaces:**
- Consumes: `LexyFrame`, `drawLexyFace(cg:frame:)` from `LexyGeometry.swift` (Task 5).
- Produces: the enclosing draw function's external signature is unchanged.

- [ ] **Step 1: Read the current body-drawing and `drawEyeShape` code**

```bash
grep -n "func usBodyPath\|private func drawEyeShape" -A 10 Heyllo/Sources/App/UploadCanvasView.swift
```

- [ ] **Step 2: Map `USEyeShape` to `EyeShape` and replace the eye-drawing call**

`USEyeShape` has three cases (`pill`, `cup`, `content`) — map them to the richer `EyeShape` vocabulary. Replace the loop that calls `drawEyeShape(ctx:shape:w:h:)`:

```swift
        var eCtx = c
        eCtx.clip(to: bp)
        let mappedEye: EyeShape = {
            switch f.eye {
            case .pill: return .pill
            case .cup: return .cup
            case .content: return .happy
            }
        }()
        for sd in [-1.0, 1.0] {
            var ec = eCtx
            ec.concatenate(CGAffineTransform(translationX: CGFloat(sd*sp+lx), y: CGFloat(ey+ly)))
            ec.withCGContext { cg in
                let frame = LexyFrame(
                    rx: ew, ry: eh, morph: 0, eye: mappedEye, eyeOpen: 1,
                    lookX: 0, lookY: 0, tint: 0, tintColor: nil,
                    bodyColor: nil, blush: 0, showBowtie: false, handsAmount: 0
                )
                drawLexyEyeDotsOnly(cg: cg, frame: frame, rx: ew, ry: eh)
            }
        }
```

This calls a narrower entry point than `drawLexyFace` — `UploadCanvasView` already draws its own body/mouth-hole (box morphing is specific to this file's suction animation and stays as-is per the spec, since it's bespoke to the upload sequence's physics, not character identity) and only needs Lexy's *eyes* drawn inside it. Add this small public wrapper to `LexyGeometry.swift` (Task 5's file) now:

```swift
/// Narrow entry point for callers (like the upload sequence) that draw their own body and
/// only need Lexy's eye-dot cluster drawn at the origin, already clipped/positioned by the
/// caller.
func drawLexyEyeDotsOnly(cg: CGContext, frame: LexyFrame, rx: CGFloat, ry: CGFloat) {
    drawLexyEyes(cg: cg, frame: frame, rx: rx, ry: ry)
}
```

(This requires changing `drawLexyEyes` from `private func` to file-scope `func` in `LexyGeometry.swift` — update that now too.)

Delete `UploadCanvasView.swift`'s old `private func drawEyeShape(ctx:shape:w:h:)` — it's replaced by the call above.

- [ ] **Step 3: Verify no leftover references**

```bash
grep -n "drawEyeShape(" Heyllo/Sources/App/UploadCanvasView.swift
```
Expected: no output.

- [ ] **Step 4: Regenerate and build**

```bash
cd Heyllo && xcodegen generate && xcodebuild -project Heyllo.xcodeproj -scheme Heyllo -configuration Debug build && cd ..
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Heyllo
git commit -m "refactor: wire UploadCanvasView eyes to LexyGeometry

UploadCanvasView's file-drop sequence had its own eye-drawing
(drawEyeShape over a local USEyeShape enum). It now maps USEyeShape to
the shared EyeShape vocabulary and calls LexyGeometry's eye-dot
renderer, so Lexy's eyes (not Mochi's) appear during the upload
animation. Body/mouth-hole geometry here is the upload sequence's own
suction-physics animation and is intentionally left as-is.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 9: Rename runtime identifiers in `HookServer.swift`

**Files:**
- Modify: `Heyllo/Sources/App/HookServer.swift`

**Interfaces:**
- Produces: all hook-install/detect/uninstall behavior keeps its existing external call signatures — only the string/path literals inside change. Task 10 depends on this task's `UserDefaults` key and matcher-string choices matching exactly.

- [ ] **Step 1: `supportDir` and both relay socket path literals**

Line 16 (`.appendingPathComponent("NotchBuddy")`) →
```swift
            .appendingPathComponent("Heyllo")
```

Line ~1168, inside the embedded `nbHookPythonGitHub` template string:
```python
'~/Library/Application Support/NotchBuddy/nb.sock'
```
→
```python
'~/Library/Application Support/Heyllo/nb.sock'
```

Line ~1331, inside the embedded `nbHookPythonAppStore` template string:
```python
'~/Library/Containers/fr.louisraille.Coucou/Data/nb.sock'
```
→ (must match Task 2's App Store bundle ID **exactly**):
```python
'~/Library/Containers/app.heyllo-appstore/Data/nb.sock'
```

- [ ] **Step 2: Hook-install directory and the `coucou`-named local variable**

Lines 692–698 (`// Write nb-hook ... into ~/.claude/coucou/`, `let coucouDir = ...appendingPathComponent("coucou")`, `coucouDir.appendingPathComponent("nb-hook")`, `coucouDir.appendingPathComponent("nb-hook.py")`):
```swift
        // Write nb-hook (shell wrapper) + nb-hook.py (Python relay) into ~/.claude/heyllo/
        let heylloDir = claudeURL.appendingPathComponent("heyllo")
        try FileManager.default.createDirectory(at: heylloDir, withIntermediateDirectories: true)
        let wrapperURL = heylloDir.appendingPathComponent("nb-hook")
        ...
        let pyURL = heylloDir.appendingPathComponent("nb-hook.py")
```
(Rename every other local use of `coucouDir` in the surrounding function to `heylloDir` — check `grep -n "coucouDir" Heyllo/Sources/App/HookServer.swift` for all occurrences in this function.)

Line 743 (`claudeURL.appendingPathComponent("coucou/nb-hook").path`) →
```swift
        let hookPath = claudeURL.appendingPathComponent("heyllo/nb-hook").path
```

- [ ] **Step 3: The four self-identifying hook-detection predicates, made rename-proof**

Each of these four sites currently checks `cmd.contains("NotchBuddy") || cmd.contains("coucou")` (or the App Store variant ordering). Per the spec and Review Focus item 2, update all four to check for the stable `"nb-hook"` substring instead of (or in addition to) the brand name, so a future rebrand doesn't repeat this exact bug. Use this pattern at all four sites (lines 585, 652, 671–673, 721–722, 758–759 — note there are slightly more than four textual occurrences because the App Store variant duplicates some checks; update every one `grep` finds):

Before (example from line 585):
```swift
                       (cmd.contains("NotchBuddy") || cmd.contains("coucou")),
```
After:
```swift
                       cmd.contains("nb-hook"),
```

Apply the same substitution — replace `cmd.contains("NotchBuddy") || cmd.contains("coucou")` (in whichever order/parenthesization it appears) with `cmd.contains("nb-hook")` — at every site this grep finds:
```bash
grep -n 'contains("NotchBuddy")\|contains("coucou")' Heyllo/Sources/App/HookServer.swift
```

- [ ] **Step 4: `UserDefaults` key**

Lines 709 and 732 (`UserDefaults.standard.set(true/false, forKey: "coucouHooksInstalled")`) →
```swift
        UserDefaults.standard.set(true, forKey: "heylloHooksInstalled")
```
and
```swift
        UserDefaults.standard.set(false, forKey: "heylloHooksInstalled")
```
(Task 10 updates the matching read site in `IslandViewContent.swift` — both must use the exact string `"heylloHooksInstalled"`.)

- [ ] **Step 5: Antigravity config key — rename on write, remove both on uninstall**

Line 805 (`let coucou = root["coucou"]`) and line 806 (`let json = (try? JSONSerialization.data(withJSONObject: coucou))`):
```swift
        guard let heyllo = root["heyllo"] else { return false }
        let json = (try? JSONSerialization.data(withJSONObject: heyllo))
```

Lines 947–960 (`var coucou: [String: Any] = [:]`, `coucou[event] = ...` ×2, `root["coucou"] = coucou`):
```swift
        var heyllo: [String: Any] = [:]
        ...
            heyllo[event] = [["matcher": "*", "hooks": [hook]]]
        ...
            heyllo[event] = [hook]
        ...
        root["heyllo"] = heyllo
```

Line 968 (`root.removeValue(forKey: "coucou")`) — per the spec, this must remove **both** keys so a pre-rebrand install's orphaned block actually gets cleaned up:
```swift
        root.removeValue(forKey: "coucou")
        root.removeValue(forKey: "heyllo")
```

- [ ] **Step 6: `coucou_agent` wire field → `heyllo_agent`, no alias**

Lines 170–172 and 352–356 (the two read sites):
```swift
        // heyllo_agent must be lowercase, digits and hyphens, ≤ 24 chars.
        let rawAgent = payload["heyllo_agent"] as? String ?? ""
```
(Apply the same change at both read sites — update the comment text too, e.g. line 157's `coucou_agent` comment and line 286's docstring.)

Inside both embedded Python templates (`nbHookPythonGitHub` around line 1142, `nbHookPythonAppStore` around line 1306):
```python
        payload.setdefault('heyllo_agent', agent)
```
Also update each template's comment line (`# --agent tags the payload with coucou_agent so...`) to say `heyllo_agent`.

- [ ] **Step 7: Error domain strings and remaining comment/doc text**

All 9 `NSError(domain: "Coucou", ...)` occurrences (and the 2 `"CoucouNoop"` occurrences, which are a distinct domain — rename those to `"HeylloNoop"`) and every `"Coucou has not touched it"` message string:
```bash
grep -n 'domain: "Coucou"\|domain: "CoucouNoop"\|Coucou has not touched it\|Coucou'"'"'s decision\|Denied from Coucou' Heyllo/Sources/App/HookServer.swift
```
Replace `"Coucou"` → `"Heyllo"`, `"CoucouNoop"` → `"HeylloNoop"`, and every `Coucou` in a user-facing message string → `Heyllo` at each matched line (including the Python template strings' `'Coucou\'s decision'` and `'Denied from Coucou'`, and the two `# Coucou hook relay` / `# nb-hook.py — Coucou hook relay` comment headers).

Also `Notification.Name("notchBuddy.hookExpand")` (line 1050) →
```swift
    static let hookExpand = Notification.Name("heyllo.hookExpand")
```

- [ ] **Step 8: Full-file verification grep**

```bash
grep -n "coucou\|Coucou\|NotchBuddy\|notchBuddy" Heyllo/Sources/App/HookServer.swift
```
Expected: no output. If anything remains, it's either a missed site from Steps 1–7 or something this plan didn't anticipate — read it and fix it before moving on; don't leave an unexplained hit.

- [ ] **Step 9: Regenerate and build**

```bash
cd Heyllo && xcodegen generate && xcodebuild -project Heyllo.xcodeproj -scheme Heyllo -configuration Debug build && cd ..
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 10: Commit**

```bash
git add Heyllo
git commit -m "refactor: rename load-bearing runtime identifiers in HookServer.swift

- supportDir and both embedded Python relays' socket-path literals
  (GitHub + App Store container path) renamed in lockstep with the new
  bundle ID from Task 2.
- Hook install directory ~/.claude/coucou/ -> ~/.claude/heyllo/.
- Four self-identifying hook-detection predicates now match the
  stable \"nb-hook\" substring instead of the brand name, so future
  rebrands don't repeat this fragility.
- UserDefaults key coucouHooksInstalled -> heylloHooksInstalled.
- Antigravity config key coucou -> heyllo on write; uninstall removes
  both keys so a pre-rebrand install's orphaned block is cleaned up.
- Wire field coucou_agent -> heyllo_agent, no back-compat alias (fresh
  project, no existing integrations to preserve).
- Error domain strings and remaining Coucou/NotchBuddy text renamed.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 10: Rename matching identifiers in `IslandViewContent.swift`

**Files:**
- Modify: `Heyllo/Sources/App/IslandViewContent.swift`

**Interfaces:**
- Consumes: must use the exact same `"heylloHooksInstalled"` `UserDefaults` key and `"nb-hook"` matcher substring chosen in Task 9.

- [ ] **Step 1: Update the `UserDefaults` read site**

Line 1154:
```swift
            return UserDefaults.standard.bool(forKey: "coucouHooksInstalled")
```
→
```swift
            return UserDefaults.standard.bool(forKey: "heylloHooksInstalled")
```

- [ ] **Step 2: Update the two hook-detection predicates**

Line 1163:
```swift
                return cmd?.contains("NotchBuddy") == true || cmd?.contains("coucou") == true
```
→
```swift
                return cmd?.contains("nb-hook") == true
```

Line 2973:
```swift
                ($0["command"] as? String)?.contains("NotchBuddy") == true
```
→
```swift
                ($0["command"] as? String)?.contains("nb-hook") == true
```

- [ ] **Step 3: Full-file verification grep**

```bash
grep -n "coucou\|Coucou\|NotchBuddy" Heyllo/Sources/App/IslandViewContent.swift
```
Expected: no output.

- [ ] **Step 4: Regenerate and build**

```bash
cd Heyllo && xcodegen generate && xcodebuild -project Heyllo.xcodeproj -scheme Heyllo -configuration Debug build && cd ..
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Heyllo
git commit -m "refactor: rename matching hook-detection identifiers in IslandViewContent.swift

Must stay in lockstep with HookServer.swift's Task 9 changes: the
UserDefaults key and the nb-hook-based matcher substring.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 11: Rename Keychain service and rewrite the system prompt in `ClaudeService.swift`

**Files:**
- Modify: `Heyllo/Sources/App/ClaudeService.swift`

**Interfaces:** None external — this is a self-contained identifier/string change.

- [ ] **Step 1: Rename the Keychain service identifier**

Line 7:
```swift
    static let service = "fr.louisraille.NotchBuddy"
```
→
```swift
    static let service = "app.heyllo"
```

This deliberately orphans any previously-saved API keys (per the spec's risk note) — there is no migration, because Keychain ACL trust is scoped to the app's code signature, which already changes with the new bundle ID from Task 2 regardless of this string's value.

- [ ] **Step 2: Rewrite the hardcoded system prompt**

Line 194:
```swift
    You are Mochi, Louis's personal AI assistant embedded in the notch of his Mac. \
```
→
```swift
    You are Lexy, the user's personal AI assistant embedded in the notch of their Mac. \
```

- [ ] **Step 3: Verify no remaining references**

```bash
grep -n "coucou\|Coucou\|NotchBuddy\|Mochi\|Louis" Heyllo/Sources/App/ClaudeService.swift
```
Expected: no output.

- [ ] **Step 4: Regenerate and build**

```bash
cd Heyllo && xcodegen generate && xcodebuild -project Heyllo.xcodeproj -scheme Heyllo -configuration Debug build && cd ..
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Heyllo
git commit -m "refactor: rename Keychain service and rewrite system prompt for Lexy

Keychain service fr.louisraille.NotchBuddy -> app.heyllo (existing
saved API keys are orphaned, unavoidably, since the new bundle ID
already changes the app's code signature). The chat system prompt no
longer hardcodes the original author's name or identity.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 12: Rename the `.coucou` state machine case to `.greeting`

**Files:**
- Modify: `Heyllo/Sources/App/IslandStateMachine.swift`
- Modify: `Heyllo/Sources/App/IslandWindowController.swift`

**Interfaces:**
- Produces: the enum case `.greeting` (was `.coucou`) on whatever enum type `IslandStateMachine.swift:12` defines it on — every call site across both files must use the new case name.

This is an **intent-named** rename, not a brand-name rename — per Review Focus item 3, don't rename it to `.heyllo`.

- [ ] **Step 1: Read the enum declaration and every call site first**

```bash
grep -n "\.coucou\b\|case coucou" Heyllo/Sources/App/IslandStateMachine.swift Heyllo/Sources/App/IslandWindowController.swift
```
Confirm this matches the spec's list: `IslandStateMachine.swift` lines 12 (declaration, with the comment `// expanded, greeting animation`), 24, 26, 38, 53, 68, 97, 105, 115; `IslandWindowController.swift` lines 163, 172, 183, 246–247, 349.

- [ ] **Step 2: Rename the case declaration**

`IslandStateMachine.swift:12`:
```swift
        case coucou   // expanded, greeting animation
```
→
```swift
        case greeting
```
(The old comment is now redundant with the clearer name — drop it.)

- [ ] **Step 3: Rename every call site**

In both files, replace every `.coucou` with `.greeting` and every `case .coucou:` with `case .greeting:`. Use the grep from Step 1 as your checklist — go through each line number and confirm the replacement compiles in context (some are pattern-match `case` statements, some are equality/assignment expressions — verify each one keeps its original semantics, just with the new case name).

- [ ] **Step 4: Verify no remaining references**

```bash
grep -n "\.coucou\b\|case coucou" Heyllo/Sources/App/IslandStateMachine.swift Heyllo/Sources/App/IslandWindowController.swift
```
Expected: no output.

- [ ] **Step 5: Regenerate and build**

```bash
cd Heyllo && xcodegen generate && xcodebuild -project Heyllo.xcodeproj -scheme Heyllo -configuration Debug build && cd ..
```
Expected: `** BUILD SUCCEEDED **`. A missed call site fails as "type has no member" — fix any that appear.

- [ ] **Step 6: Commit**

```bash
git add Heyllo
git commit -m "refactor: rename IslandStateMachine .coucou case to .greeting

This is a state machine enum case, not a brand string, so it's renamed
to something intent-based rather than to .heyllo — otherwise a
mechanical brand-name sweep would have quietly corrupted a piece of
application logic instead of just renaming a string.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 13: Rename remaining user-facing strings and paths

**Files:**
- Modify: `Heyllo/Sources/App/AppDelegate.swift`
- Modify: `Heyllo/Sources/App/SettingsView.swift`
- Modify: `Heyllo/Sources/App/AppLog.swift`

**Interfaces:** None external — self-contained string/path changes.

- [ ] **Step 1: `AppDelegate.swift`**

Line 24:
```swift
        button.image = NSImage(named: "MenuBarIcon") ?? NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Coucou")
```
→
```swift
        button.image = NSImage(named: "MenuBarIcon") ?? NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Heyllo")
```

Line 26:
```swift
        button.image?.accessibilityDescription = "Coucou"
```
→
```swift
        button.image?.accessibilityDescription = "Heyllo"
```

Line 30:
```swift
        menu.addItem(withTitle: "Open Coucou", action: #selector(openIsland), keyEquivalent: "")
```
→
```swift
        menu.addItem(withTitle: "Open Heyllo", action: #selector(openIsland), keyEquivalent: "")
```

Line 58:
```swift
        win.title = "Settings — Coucou"
```
→
```swift
        win.title = "Settings — Heyllo"
```

- [ ] **Step 2: `SettingsView.swift`**

Line 179:
```swift
                        Text("~/.claude/coucou/nb-hook")
```
→
```swift
                        Text("~/.claude/heyllo/nb-hook")
```

Line 444:
```swift
                        Text("Choose the tools you use. Coucou only shows what you declare here.")
```
→
```swift
                        Text("Choose the tools you use. Heyllo only shows what you declare here.")
```

Lines 593–594:
```swift
        alert.messageText = "Install Coucou hooks in ~/.claude?"
        alert.informativeText = "Will write:\n• ~/.claude/coucou/nb-hook\n• ~/.claude/settings.json (backup created first)"
```
→
```swift
        alert.messageText = "Install Heyllo hooks in ~/.claude?"
        alert.informativeText = "Will write:\n• ~/.claude/heyllo/nb-hook\n• ~/.claude/settings.json (backup created first)"
```

Lines 657 and 684 (`catch let e as NSError where e.domain == "CoucouNoop"`) — must match Task 9's Step 7 rename:
```swift
        } catch let e as NSError where e.domain == "HeylloNoop" {
```

- [ ] **Step 3: `AppLog.swift`**

Line 13 (doc comment):
```swift
/// Appends one timestamped line to `~/Library/Logs/NotchBuddy/<fileName>`.
```
→
```swift
/// Appends one timestamped line to `~/Library/Logs/Heyllo/<fileName>`.
```

Line 21:
```swift
        .appendingPathComponent("Logs/NotchBuddy")
```
→
```swift
        .appendingPathComponent("Logs/Heyllo")
```

- [ ] **Step 4: Full verification grep across all three files**

```bash
grep -n "coucou\|Coucou\|NotchBuddy\|CoucouNoop" Heyllo/Sources/App/AppDelegate.swift Heyllo/Sources/App/SettingsView.swift Heyllo/Sources/App/AppLog.swift
```
Expected: no output.

- [ ] **Step 5: Regenerate and build**

```bash
cd Heyllo && xcodegen generate && xcodebuild -project Heyllo.xcodeproj -scheme Heyllo -configuration Debug build && cd ..
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add Heyllo
git commit -m "refactor: rename remaining user-facing strings and log path

AppDelegate's menu bar text/accessibility strings, SettingsView's hook
install path and alert text, and AppLog's log directory all move from
Coucou/NotchBuddy to Heyllo.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 14: Rewrite `docs/AGENTS.md`, `docs/SPEC.md`, `docs/INTEGRATIONS.md`, and the legal/support HTML pages

**Files:**
- Modify: `docs/AGENTS.md`
- Modify: `docs/SPEC.md`
- Modify: `docs/INTEGRATIONS.md`
- Modify: `docs/index.html`, `docs/support.html`, `docs/privacy.html`, `docs/terms.html`, `docs/legal.html`

**Interfaces:** Consumes Task 9's `heyllo_agent` field name and the new socket paths — `docs/AGENTS.md` is the published contract for third-party integrations and must describe the real, current wire format.

- [ ] **Step 1: Rewrite `docs/AGENTS.md`**

Read the current file first (`cat docs/AGENTS.md`), then rewrite every reference:
- `coucou_agent` → `heyllo_agent` (field name, in all JSON examples and prose)
- `/path/to/nb-hook` examples stay (the script name itself doesn't change)
- `~/Library/Application Support/NotchBuddy/nb.sock` → `~/Library/Application Support/Heyllo/nb.sock`
- `~/Library/Containers/fr.louisraille.Coucou/Data/nb.sock` → `~/Library/Containers/app.heyllo-appstore/Data/nb.sock`
- Every prose reference to "Coucou" → "Heyllo"
- The Windows/Linux sections (`coucou-hook.exe`, `~/.local/share/coucou/bin/coucou-hook`, `coucou.sock`, `coucou-<user-SID>`) — leave these **unchanged**, since Windows/Linux is out of scope per the spec and this plan; only the macOS-relevant content changes.

- [ ] **Step 2: Rewrite `docs/SPEC.md` and `docs/INTEGRATIONS.md`**

```bash
grep -n "coucou\|Coucou\|NotchBuddy\|Mochi" docs/SPEC.md docs/INTEGRATIONS.md
```
Read each matched line in context and rewrite it for the new name/field, following the same rules as Step 1 (macOS-relevant content only; `coucou_agent` → `heyllo_agent`; socket paths updated).

- [ ] **Step 3: Review and rewrite the legal/support HTML pages**

These name the old app in a compliance context (privacy policy, terms of service), so read each one fully before editing — don't blind find-replace a legal document.

```bash
grep -n "Coucou\|coucou" docs/index.html docs/support.html docs/privacy.html docs/terms.html docs/legal.html
```

For each match: if it's purely a name reference ("Coucou collects no telemetry" → "Heyllo collects no telemetry"), rename it directly. If it references a URL, contact method, or legal entity specific to the original author/project (e.g. a GitHub issues link pointing at `Louis-CFM/coucou`, or an email address), do not silently repoint it to the original author's contact details — flag it in the commit message as needing the fork owner's own contact information, and leave a `<!-- TODO(heyllo): replace with your own contact/issue-tracker link -->` HTML comment at that exact spot so it's easy to find later. (This is the one place in this plan where a literal `TODO` marker is correct, since the actual destination — the user's own GitHub repo/contact — isn't yet known to this plan.)

- [ ] **Step 4: Verify**

```bash
grep -rn "coucou\|Coucou" docs/*.md docs/*.html
```
Expected: no output, except any `TODO(heyllo)` comments you deliberately left in Step 3 pointing at contact/issue-tracker links.

- [ ] **Step 5: Commit**

```bash
git add docs
git commit -m "docs: rebrand AGENTS.md, SPEC.md, INTEGRATIONS.md, and legal/support pages

coucou_agent -> heyllo_agent throughout the third-party integration
contract, both macOS socket paths updated, Windows/Linux sections left
untouched (out of scope). Legal/support HTML pages reviewed and
rewritten by hand, not blind find-replaced, since they're compliance
documents; any link specific to the original author's own repo/contact
is marked with a TODO rather than silently repointed.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 15: Rewrite root docs, GitHub templates/workflows, and scripts

**Files:**
- Modify: `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `CLAUDE.md`
- Modify: `.github/ISSUE_TEMPLATE/*.md`
- Modify: `.github/workflows/build.yml`, `.github/workflows/release.yml`
- Modify: `scripts/release.sh`, `scripts/test-safe-links.sh`, `scripts/test-screen-geometry.sh`

**Interfaces:** None external — the CI workflows' changes affect what folder/project/scheme name CI invokes, which must match Task 2's `Heyllo`/`Heyllo.xcodeproj`/`Heyllo` exactly.

- [ ] **Step 1: Rewrite `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `CLAUDE.md`**

Read each file fully first. Rename "Coucou" → "Heyllo" and "Mochi" → "Lexy" throughout the prose, keeping the document structure. Drop any content tied specifically to removed media (Task 1) or to character-art descriptions that no longer apply (e.g. the README's "squircle" visual description, if present, should describe Lexy's dot-cluster look instead). The `CHANGELOG.md`'s historical entries describing past Coucou versions may be left as historical record (add them to the Task 18 verification allowlist rather than rewriting history) — use judgment here: a changelog entry describing what version 0.1.1 *did* under the old name is a historical fact, not a branding string to scrub.

- [ ] **Step 2: Rewrite `.github/ISSUE_TEMPLATE/*.md`**

```bash
grep -rln "Coucou\|coucou\|Mochi" .github/ISSUE_TEMPLATE/
```
Rename matched text in each file the same way as Step 1.

- [ ] **Step 3: Update `.github/workflows/build.yml` and `release.yml` — structural build inputs, not text**

```bash
grep -n "NotchBuddy\|Coucou" .github/workflows/build.yml .github/workflows/release.yml
```
Replace `cd NotchBuddy` → `cd Heyllo`, `-project NotchBuddy/NotchBuddy.xcodeproj` → `-project Heyllo/Heyllo.xcodeproj`, `-scheme NotchBuddy` → `-scheme Heyllo`, and any other folder/project/scheme references these files make, matching Task 2's exact names.

- [ ] **Step 4: Update `scripts/release.sh`, `scripts/test-safe-links.sh`, `scripts/test-screen-geometry.sh`**

In `scripts/release.sh`:
```bash
BUILD_DIR="/tmp/coucou-release-$VERSION"
APP="$BUILD_DIR/Coucou.app"
ZIP="$BUILD_DIR/Coucou.zip"
```
→
```bash
BUILD_DIR="/tmp/heyllo-release-$VERSION"
APP="$BUILD_DIR/Heyllo.app"
ZIP="$BUILD_DIR/Heyllo.zip"
```
and:
```bash
cd "$REPO_ROOT/NotchBuddy"
xcodegen generate
...
xcodebuild \
  -project NotchBuddy.xcodeproj \
  -scheme NotchBuddy \
```
→
```bash
cd "$REPO_ROOT/Heyllo"
xcodegen generate
...
xcodebuild \
  -project Heyllo.xcodeproj \
  -scheme Heyllo \
```
and:
```bash
xcrun notarytool submit "$ZIP" --keychain-profile coucou-notary --wait
```
→
```bash
xcrun notarytool submit "$ZIP" --keychain-profile heyllo-notary --wait
```
Also check for and update any `--repo Louis-CFM/coucou` reference (this one needs the fork owner's actual GitHub repo path — leave a `# TODO(heyllo): set to your own GitHub repo` comment at that line rather than guessing it, same rule as Task 14's Step 3). This script's actual notarization flow still depends on the user's own Apple Developer credentials (out of scope per the spec) — it's corrected for consistency but not exercised end-to-end.

For `scripts/test-safe-links.sh` and `scripts/test-screen-geometry.sh`:
```bash
grep -n "NotchBuddy\|Coucou\|coucou" scripts/test-safe-links.sh scripts/test-screen-geometry.sh
```
Update any matched path/name references the same way.

- [ ] **Step 5: Verify**

```bash
grep -rln "NotchBuddy\|Coucou\|coucou" README.md CHANGELOG.md CONTRIBUTING.md CLAUDE.md .github/ scripts/ | grep -v CHANGELOG.md
```
Expected: no output (the `CHANGELOG.md` exclusion is deliberate per Step 1's historical-record judgment call — review its remaining hits manually to confirm they're genuinely historical, not missed renames).

- [ ] **Step 6: Commit**

```bash
git add README.md CHANGELOG.md CONTRIBUTING.md CLAUDE.md .github scripts
git commit -m "docs: rebrand root docs, GitHub templates, workflows, and scripts

CI workflows and scripts/release.sh updated with the new folder/
project/scheme names as structural build inputs, not just text.
CHANGELOG.md's historical entries describing past Coucou-named
releases are left as a historical record.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 16: Rewrite `LICENSE-ASSETS.md`

**Files:**
- Modify: `LICENSE-ASSETS.md`

**Interfaces:** None.

- [ ] **Step 1: Replace the file's content**

```markdown
# Heyllo — name, character and artwork

Copyright (c) 2026 [Your name]. All rights reserved, except as stated below.

The [MIT License](LICENSE) covers the **source code** of this project (originally forked from
[Louis-CFM/coucou](https://github.com/Louis-CFM/coucou), whose own copyright notice is retained
in `LICENSE` as required by its terms). It does **not** cover the brand and the artwork listed
here, which are the property of this fork's author:

- the names **"Heyllo"** and **"Lexy"**;
- the **Lexy character** — its design, look, expressions and animations as a character;
- the **app icon** and **menu bar icon** (`Heyllo/Assets.xcassets/`);
- the **sounds** (`Heyllo/Resources/sounds/`);
- any images, GIFs and videos depicting Lexy or the Heyllo brand added to this repository.

## What you can do

- Build and run Heyllo from this repository, for yourself, as it is.
- Fork it and contribute back with pull requests.
- Show, review, write or talk about Heyllo (articles, videos, posts), including screenshots.

## What you can't do without written permission

- Publish or distribute an app, a fork or a derivative work under the name "Heyllo" or "Lexy",
  or with the Heyllo icon, the Lexy character or the Heyllo sounds — on the App Store, on
  GitHub releases, or anywhere else.
- Use any of these assets commercially, or in a way that suggests your project is Heyllo or is
  made or endorsed by its author.

If you fork Heyllo to ship your own app, that's welcome under the MIT License: just give it
**your own name, icon, character and sounds** — the same courtesy this project extended to the
original Coucou/Mochi project it was forked from.

## Questions or permission requests

[Add your own contact method or GitHub issues link here.]
```

Replace `[Your name]` and the final contact line with the fork owner's actual information before shipping — leave the brackets as a visible placeholder for now since this plan doesn't have that information, and note it in the commit message.

- [ ] **Step 2: Verify**

```bash
grep -n "Louis Raillé\|raillelouis@gmail.com\|Mochi\|Coucou" LICENSE-ASSETS.md
```
Expected: no output (the one intentional exception is the `LICENSE` file itself, which is never touched per Global Constraints — confirm this grep is scoped to `LICENSE-ASSETS.md` only, not `LICENSE`).

- [ ] **Step 3: Commit**

```bash
git add LICENSE-ASSETS.md
git commit -m "docs: rewrite LICENSE-ASSETS.md for Heyllo/Lexy

Describes the new name, character, icon, and sounds as this fork's own
protected assets, with no remaining reference to the original Coucou/
Mochi assets since none of them ship here anymore. The copyright-holder
name and contact method are left as placeholders pending the fork
owner's own details — LICENSE's MIT notice is untouched per the spec.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 17: Placeholder sound and icon assets

**Files:**
- Modify: `Heyllo/Resources/sounds/*.wav` (all 28 files)
- Modify: `Heyllo/Assets.xcassets/AppIcon.appiconset/*.png` (all 10 sizes)
- Modify: `Heyllo/Assets.xcassets/MenuBarIcon.imageset/*` (whatever files that imageset contains)

**Interfaces:** None — pure asset replacement, no code changes (per the spec, `SoundEngine.swift` and the `AppDelegate.swift` icon lookup need no changes since filenames/catalog names are unchanged).

The actual new recordings and icon artwork are creative deliverables outside this plan's scope (per the spec's risk notes) — this task's job is only to make sure placeholder assets exist so the app builds and runs with *something* in every slot, not Mochi's original proprietary files. Treat this task as a clearly-marked manual/creative step, not an automated one.

- [ ] **Step 1: Generate placeholder sounds**

Replace each of the 28 `.wav` files with a minimal, distinct placeholder tone (not silence, so the app's audio-feedback behavior is still testable) using `afplay`-compatible `sox` or `afinfo`-checked raw generation. If `sox` isn't installed (`which sox`), install it first: `brew install sox`.

```bash
cd Heyllo/Resources/sounds
for f in annoyed approval approve attach blip close dizzy error finish greet gulp hover love open peek pop proud question rate search send slap sleep think tick wink work yawn; do
  sox -n "$f.wav" synth 0.15 sine 440 vol 0.3
done
cd ../../..
```

This produces 28 identical short beeps — a functional placeholder, not final art. Note in the commit message that real sound design is a follow-up task.

- [ ] **Step 2: Generate placeholder icon artwork**

Replace the `AppIcon.appiconset` PNGs with a simple solid-color square bearing Lexy's silhouette concept (a plain colored square is an acceptable placeholder — don't spend implementation effort hand-designing final icon art here). Using `sips` (built into macOS) to generate each required size from one source placeholder:

```bash
cd Heyllo/Assets.xcassets/AppIcon.appiconset
# Create one 1024x1024 placeholder (solid color — replace with real art later)
# using Python + Pillow if available, else a plain ImageMagick fill:
if command -v convert >/dev/null; then
  convert -size 1024x1024 xc:'#2B2D42' placeholder_1024.png
else
  echo "Install imagemagick (brew install imagemagick) to generate a placeholder icon." >&2
  exit 1
fi
for size_pair in "16:icon_16x16.png" "32:icon_16x16@2x.png" "32:icon_32x32.png" "64:icon_32x32@2x.png" "128:icon_128x128.png" "256:icon_128x128@2x.png" "256:icon_256x256.png" "512:icon_256x256@2x.png" "512:icon_512x512.png" "1024:icon_512x512@2x.png"; do
  size="${size_pair%%:*}"
  name="${size_pair##*:}"
  sips -z "$size" "$size" placeholder_1024.png --out "$name" >/dev/null
done
rm placeholder_1024.png
cd ../../../..
```

Check `Contents.json` in `MenuBarIcon.imageset` for its exact expected filenames/sizes before generating its replacement the same way.

- [ ] **Step 3: Build and confirm the app launches**

```bash
cd Heyllo && xcodegen generate && xcodebuild -project Heyllo.xcodeproj -scheme Heyllo -configuration Debug build && cd ..
open Heyllo/build/Debug/Heyllo.app
```
Expected: the app launches, the menu bar icon shows the placeholder art (not a broken-image icon), and — per the main Verification section's smoke check — some sound plays on a triggered event (e.g. the greeting sound on launch).

- [ ] **Step 4: Commit**

```bash
git add Heyllo/Resources/sounds Heyllo/Assets.xcassets
git commit -m "chore: placeholder sounds and icon art for Heyllo/Lexy

The original 28 sound files and app/menu-bar icon were Mochi/Coucou
proprietary art and were deleted. These placeholders (simple tones, a
solid-color icon) make the app buildable and testable with no
proprietary assets; real sound recordings and icon design are a
separate creative follow-up, not part of this rebrand's code changes.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 18: Final verification pass

**Files:** None modified — this task only verifies prior tasks.

**Interfaces:** None.

- [ ] **Step 1: Allowlist-gated grep sweep**

```bash
grep -ril "coucou\|mochi" . --exclude-dir=.git --exclude-dir=windows --exclude-dir=node_modules
```

Expected matches, and only these (build the allowlist file in Step 2 from whatever this actually returns):
- `CHANGELOG.md` — historical entries about past Coucou-named releases (per Task 15's judgment call)
- `docs/superpowers/specs/2026-10-02-heyllo-rebrand-design.md` and this plan file — they describe the rename itself and necessarily say the old names
- Any `TODO(heyllo)` comments left in Task 14/15 pointing at contact/repo links not yet known

If anything else appears, it's a missed rename — go fix it in the relevant earlier task's file before continuing (don't patch it ad hoc outside any task's scope; amend the appropriate task's commit by adding a new small follow-up commit referencing which task it completes).

- [ ] **Step 2: Write the allowlist**

Create `docs/superpowers/specs/2026-10-02-heyllo-rebrand-allowlist.md`:

```markdown
# Heyllo rebrand — intentional "coucou"/"mochi" occurrences

Per the verification gate in docs/superpowers/specs/2026-10-02-heyllo-rebrand-design.md,
`grep -ril "coucou|mochi"` (excluding .git/ and windows/) should match only the entries below.
Any other match is a bug.

- `CHANGELOG.md` — historical changelog entries describing past releases under the old name.
- `docs/superpowers/specs/2026-10-02-heyllo-rebrand-design.md` — describes the rename itself.
- `docs/superpowers/plans/2026-10-02-heyllo-rebrand.md` — this plan, same reason.
- `docs/superpowers/specs/2026-10-02-heyllo-rebrand-allowlist.md` — this file.
- [Add any TODO(heyllo) comment locations from Task 14/15 here, with their file:line.]
```

- [ ] **Step 3: Confirm no stale `.xcodeproj` and a clean regeneration**

```bash
find . -iname "NotchBuddy.xcodeproj" -not -path "./.git/*"
```
Expected: no output.

```bash
cd Heyllo && xcodegen generate && cd ..
git status Heyllo/Heyllo.xcodeproj
```
Expected: the regenerated project either matches what's already committed (no diff) or is correctly gitignored per Task 2 — confirm which policy this repo actually uses by checking `.gitignore`, and that the working tree is clean either way.

- [ ] **Step 4: Debug build for both targets**

```bash
cd Heyllo
xcodebuild -project Heyllo.xcodeproj -scheme Heyllo -configuration Debug build
xcodebuild -project Heyllo.xcodeproj -scheme HeylloAppStore -configuration Debug build
cd ..
```
Expected: `** BUILD SUCCEEDED **` for both.

- [ ] **Step 5: End-to-end hook test, both build configurations**

For the GitHub build: launch `Heyllo.app`, use Settings → Install hooks, then run:
```bash
echo '{"hook_event_name":"UserPromptSubmit","session_id":"verify-1","prompt":"hello"}' \
  | /bin/sh ~/Library/Application\ Support/Heyllo/nb-hook
```
Expected: the running app shows a pill transition to "thinking" state for session `verify-1`.

For the App Store build: launch the `HeylloAppStore` scheme's built app, install hooks via its Settings UI, then send the same test payload through its installed `nb-hook` (per the app's own install-path label in Settings, from Task 13). Expected: same pill-state observation, confirming the container socket path from Task 9 Step 1 is correct.

- [ ] **Step 6: Hook reinstall/uninstall idempotency**

With the GitHub build running: Settings → Install hooks (first install), then Settings → Install hooks again (reinstall). Inspect `~/.claude/settings.json`:
```bash
grep -c "nb-hook" ~/.claude/settings.json
```
Expected: the count does not grow between the first and second install (no duplicate entry appended — this exercises Task 9's `"nb-hook"`-based matcher fix). Then Settings → Uninstall hooks, and confirm:
```bash
grep -c "nb-hook" ~/.claude/settings.json
```
Expected: `0`.

- [ ] **Step 7: Visual smoke check across all three character render sites**

Launch the app and observe:
1. The main island pill in at least three different states (e.g. idle, working, approval) — confirm Lexy's dot-face and bowtie render without crashing or obvious geometry glitches.
2. Quit and relaunch the app to trigger the greeting animation — confirm it shows Lexy, not the old Mochi silhouette.
3. Drag a file onto the island to trigger the upload sequence — confirm Lexy's eyes (dot-based, per Task 8) render during the box/suction animation.

This is a manual check — there's no automated UI test harness for this app (per Global Constraints). Note the outcome in the final commit message.

- [ ] **Step 7b: Confirm Keychain save/read works under the new service identifier**

Per Review Focus item 5, Task 11's Keychain service rename isn't exercised by any build/grep check — verify it manually now: open Settings → Anthropic API, enter any test API key value, save it, then quit and relaunch the app and confirm Settings still shows the key as saved (read-back succeeds). This confirms `app.heyllo` works as a Keychain service identifier end-to-end; it does **not** need to confirm the key is a *valid* Anthropic key, just that save/read round-trips under the new identifier. Do not attempt to migrate or recover any key saved under the old `fr.louisraille.NotchBuddy` identifier — per the spec, that's expected to be orphaned, not a bug.

- [ ] **Step 8: Commit the allowlist and verification notes**

```bash
git add docs/superpowers/specs/2026-10-02-heyllo-rebrand-allowlist.md
git commit -m "docs: add Heyllo rebrand verification allowlist

Final verification pass complete: allowlist-gated grep sweep clean,
no stale NotchBuddy.xcodeproj, Debug builds succeed for both targets,
end-to-end hook test passes for both build configurations, hook
reinstall/uninstall is idempotent, and a manual visual smoke check
confirmed Lexy renders correctly across the main pill, the greeting
animation, and the upload sequence.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---
