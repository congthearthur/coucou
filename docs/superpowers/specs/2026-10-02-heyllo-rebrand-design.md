# Heyllo rebrand (macOS) — design spec

_Revision 2 — amended after architecture + security review (see "Review history" at the end)._

## Why

This repo is a fork of [Louis-CFM/coucou](https://github.com/Louis-CFM/coucou). Its source
code is MIT-licensed, but per `LICENSE-ASSETS.md`, the name "Coucou", the character "Mochi",
the app/menu-bar icon, the sounds, and the media in `docs/media/` and `design/` remain the
exclusive property of the original author and may not ship in a distributed fork. To publish
this fork under its own identity, those assets must be replaced; the underlying engineering
(state machine, hooks, integrations) is unaffected and stays.

## Scope

**In scope:** the macOS app (`NotchBuddy/` → `Heyllo/`), repo-root branding (README, CHANGELOG,
CONTRIBUTING, CLAUDE.md, GitHub issue templates, macOS-relevant workflow content), removal of
proprietary demo media, `docs/` (AGENTS.md, SPEC.md, INTEGRATIONS.md, the legal/support HTML
pages), and `scripts/` (release and test scripts that hardcode the old name/paths).

**Out of scope (explicitly deferred):**
- Windows/Linux (`windows/`) — code and docs untouched this pass.
- Functional improvements beyond the rebrand — separate future spec.
- New demo screenshots/GIFs/video of Lexy — needs a working build first.
- **Release/App Store code signing and notarization** — the existing `DEVELOPMENT_TEAM`
  belongs to the original author and cannot be reused. This pass only needs to produce a
  working **Debug** build under the new identity (automatic/ad-hoc signing). Release signing is
  a prerequisite the user fulfills later with their own Apple Developer Team ID.
- French-language usage-description strings (`NSAppleEventsUsageDescription`,
  `NSAccessibilityUsageDescription`, the ticker's French verb labels) — left as-is, a
  deliberate deferral, not an oversight.

## New identity

| Old | New |
|---|---|
| App name "Coucou" | **Heyllo** |
| Character "Mochi" | **Lexy** |
| Project folder `NotchBuddy/` | `Heyllo/` |
| Xcode target `NotchBuddy` | `Heyllo` |
| Xcode target `CoucouAppStore` | `HeylloAppStore` |
| Bundle ID `fr.louisraille.NotchBuddy` | `app.heyllo` |
| Bundle ID `fr.louisraille.Coucou` | `app.heyllo-appstore` (sibling, not nested, to keep future app-group/keychain-group IDs unambiguous) |
| `bundleIdPrefix` in `project.yml` | `app.heyllo` |
| Entitlements `Coucou.entitlements` | `Heyllo.entitlements` |
| Entitlements `CoucouAppStore.entitlements` | `HeylloAppStore.entitlements` |
| `MochiConst` enum | `LexyConst` (moves into `LexyGeometry.swift`, see §1) |
| `NotchBuddyApp.swift` / `struct NotchBuddyApp: App` | `HeylloApp.swift` / `struct HeylloApp: App` |
| `supportDir` ("NotchBuddy" component, `HookServer.swift`) | `"Heyllo"` → `~/Library/Application Support/Heyllo` |
| Hook install dir `~/.claude/coucou/` | `~/.claude/heyllo/` |
| Keychain service `fr.louisraille.NotchBuddy` (`ClaudeService.swift`) | `app.heyllo` (see risk note — this orphans existing saved keys) |
| Wire field `coucou_agent` | `heyllo_agent` (no back-compat alias — see §5 rationale) |
| Antigravity config top-level key `"coucou"` (`~/.gemini/config/hooks.json`) | `"heyllo"`, with removal code for **both** old and new key |
| `UserDefaults` key `"coucouHooksInstalled"` | `"heylloHooksInstalled"` |
| `AppLog` path `~/Library/Logs/NotchBuddy` | `~/Library/Logs/Heyllo` |
| `Notification.Name("notchBuddy.hookExpand")` | `Notification.Name("heyllo.hookExpand")` |
| `IslandStateMachine` case `.coucou` (the greeting state) | `.greeting` — **intent-named, not brand-named**; this is a state machine case, not a string, and a blind find-replace would corrupt it |
| `aliasProjectName` mapping (`notch-buddy`/`notchbuddy`/`notch_buddy` → `"Notch Buddy"`) | removed — no longer meaningful |

The `nb-hook` script name predates the "Coucou" marketing name and is not a protected brand
asset — it stays as-is, and (per §5) becomes the *more robust* identifier for self-detection
logic going forward.

Character visual concept: a small cluster of dots forming a face (in the style of recent
minimal dot/blob marks), with a small dot-built bowtie as Lexy's one signature accessory —
cute, with a light "professional" cue. Sound set: new recordings, same 28 filenames, a
soft/professional tone rather than the original's playful chimes.

## Design

### 1. Character rendering

**The character is drawn independently in three places, not one.** `BotEngine.swift` draws the
main island pill. `GreetingCanvasView.swift` has its own complete, separate implementation
(`mochiPath` with a different superellipse exponent, `drawMochi`, `drawHandL`/`drawHandR`, its
own eye drawing, its own `drawParticles`) for the launch greeting. `UploadCanvasView.swift` has
a third independent implementation (`drawEyeShape` over its own `USEyeShape` enum, its own
body/mouth/rim geometry) for the file-drop sequence. All three must be redesigned for Lexy, or
Mochi will still appear in the greeting and upload animations after the pill is rebranded.

**Shared geometry module.** Create `Heyllo/Sources/App/LexyGeometry.swift` as the single source
of Lexy's visual design, used by all three call sites:
- Dot-cluster face geometry and the bowtie shape.
- The mapping from each `EyeShape` case (pill, wide, dot, line, flat, happy, closed, spiral,
  heart, star, tired, wink, cup) to a dot arrangement. `EyeShape` itself moves here from
  `BotEngine.swift` (it's renderer vocabulary, also consumed by `IslandTypes.swift`).
- `LexyConst` (renamed from `MochiConst`) — tunable constants.
- Hand/limb geometry (currently `drawHandsBehind`/`drawHandsAndExtras` in `BotEngine.swift`,
  and `drawHandL`/`drawHandR` in `GreetingCanvasView.swift`) — redesigned for Lexy's dot-cluster
  form, unified into one implementation both call sites use.
- `drawBadge` and `drawParticles` (currently private in `BotEngine.swift`) and the `heartShape`/
  `starShape` file-scope helpers — move here so all three renderers share one definition instead
  of duplicating.
- Shared math/color helpers (`lerp`, `clamp`, `cgColorToTuple`, `mix3`, `colorFromTuple`, `Ease`)
  — currently `private` at file scope in `BotEngine.swift`, so a new file can't use them as-is.
  Move to `Heyllo/Sources/App/DrawMath.swift` (or into `LexyGeometry.swift` if small enough) so
  `BotEngine`, `GreetingCanvasView`, and `UploadCanvasView` all compile against one copy.
- `USEyeShape` (the upload sequence's analogous enum) gets its dot-cluster geometry ported too,
  reusing `LexyGeometry`'s primitives rather than hand-rolling a fourth implementation.

**Interface and ownership boundary.** `BotEngine.swift` keeps its state machine exactly as-is:
`BotStateCfg`, timing, emotes, `update(dt:)`, and the logic that currently lives inside
`drawEyes` deciding *which* `EyeShape` to show (`eyeOverride ?? cfg.eye`, overridden to `.happy`
while chewing or `.cup` during a slot animation). That resolution logic **stays in
`BotEngine`** — it is state-machine policy, not geometry. `BotEngine.draw(context:size:)`
resolves the active `EyeShape` and the ~25 other fields the old drawing code touched
(`morph`, `slotH`, `yaw`/`pitch`/`roll`, `bodyColor`, `blush`, `sx`/`sy`/`ox`/`oy`, `tilt`,
particles, etc.) into a single immutable snapshot — `LexyFrame` — and passes *only that
struct* into `LexyGeometry`'s draw function. `GreetingCanvasView` and `UploadCanvasView`
construct their own `LexyFrame` values from their own (much simpler) state. This is the
boundary that prevents the renderer from becoming a second place that reads engine internals.

**File-size note:** extracting the above removes roughly 450–600 of `BotEngine.swift`'s 1,504
lines. That's a meaningful reduction but may not get the file under the project's 800-line
guideline on its own; a further split (e.g. the `BotStates` config table, the tween engine) is
a reasonable follow-up but isn't required by this spec and shouldn't block it.

### 2. Sounds

Replace the contents of the 28 existing `.wav` files in `NotchBuddy/Resources/sounds/`
(annoyed, approval, approve, attach, blip, close, dizzy, error, finish, greet, gulp, hover,
love, open, peek, pop, proud, question, rate, search, send, slap, sleep, think, tick, wink,
work, yawn) with new recordings/compositions matching a soft/professional tone. Filenames are
unchanged — `SoundEngine.swift`'s `preload()` and the `players` dict require no code changes.

### 3. Icon

Replace artwork in `Assets.xcassets/AppIcon.appiconset/` (all mac idiom sizes, @1x/@2x) and in
the `MenuBarIcon` imageset. Asset catalog entry names (`AppIcon`, `MenuBarIcon`) are unchanged,
so `AppDelegate.swift`'s `NSImage(named: "MenuBarIcon")` lookup needs no code change — only the
image contents.

### 4. Proprietary media removal

Delete entirely (all depict Mochi/Coucou and are proprietary under `LICENSE-ASSETS.md`):
- `docs/media/` — `chat.png`, `claude-code.png`, `coucou.png`, `demo.gif`, `demo.mp4`,
  `dizzy.png`, `icon.png`, `stripe.png`, `upload.png`.
- `design/` — `captures/` (34 screenshots), `prototype/notch-buddy.html`,
  `animations/greeting-v2.html`, `animations/upload-sequence.html`.

`README.md` references to this media are rewritten to describe Heyllo/Lexy without broken
image links. New screenshots of the actual running Heyllo app are a follow-up task once the
character/icon/sound work is built and testable — not part of this spec.

### 5. Renaming sweep

Every item below is verified individually (not just by a final blind grep — see Verification).

**Xcode project structure**
- Delete the committed `NotchBuddy/NotchBuddy.xcodeproj/` outright (don't leave it alongside a
  newly generated one). Move `NotchBuddy/` → `Heyllo/`, update `project.yml` in place (target
  names, `bundleIdPrefix`, bundle identifiers, entitlements references), regenerate via
  `xcodegen` into `Heyllo.xcodeproj`. Confirm `.gitignore` treats the generated `.xcodeproj`
  consistently (don't let a stale copy get re-committed). Delete the stray `NotchBuddy/.DS_Store`.
- `NotchBuddyApp.swift` → `HeylloApp.swift`, `struct NotchBuddyApp: App` → `struct HeylloApp: App`.
- `project.yml`: `DEVELOPMENT_TEAM` (currently the original author's team ID, two places) is
  cleared/set for automatic signing on Debug; Release-config signing is out of scope (see Scope).

**Runtime identifiers (the part most likely to silently break the hook pipeline)**
- `HookServer.swift`: `supportDir`'s `"NotchBuddy"` component → `"Heyllo"`. Both embedded Python
  relay templates have **hardcoded socket path literals that must change in lockstep**:
  `nbHookPythonGitHub`'s `'~/Library/Application Support/NotchBuddy/nb.sock'` and
  `nbHookPythonAppStore`'s `'~/Library/Containers/fr.louisraille.Coucou/Data/nb.sock'` (the
  latter must track the new App Store bundle ID exactly, or the relay connects to a socket that
  doesn't exist and fails silently — it swallows errors by design). Hook install path logic
  updated to `~/.claude/heyllo/`.
- Self-identifying hook matchers currently check `cmd.contains("NotchBuddy") || cmd.contains("coucou")`
  in **four** places in `HookServer.swift` (`hooksNeedUpdate`, `buildHooksData`,
  `uninstallClaudeHooks`, and the App Store variants) **and two more in `IslandViewContent.swift`**
  (install-state detection). Update all six to match the new name, and additionally match on the
  stable `"nb-hook"` substring (as the Gemini/Antigravity code paths already do) so future
  rebrands don't repeat this fragility.
- `UserDefaults` key `"coucouHooksInstalled"` → `"heylloHooksInstalled"` — update the write site
  (`HookServer.swift`) and read site (`IslandViewContent.swift`) together; a mismatch leaves the
  App Store "configured" indicator permanently wrong.
- Antigravity hooks config (`~/.gemini/config/hooks.json`): the top-level key written by
  `buildAgyHooksData()`, read by `agyHooksInstalled()`, and removed by `withoutAgyHooks()`
  changes from `"coucou"` to `"heyllo"`. `withoutAgyHooks()` must remove **both** keys, so a
  pre-rebrand install's orphaned `"coucou"` block actually gets cleaned up instead of lingering
  forever.
- `AppLog.swift` log path `~/Library/Logs/NotchBuddy` → `~/Library/Logs/Heyllo`.
  `Notification.Name("notchBuddy.hookExpand")` → `Notification.Name("heyllo.hookExpand")`.
  `aliasProjectName`'s `notch-buddy`/`notchbuddy`/`notch_buddy` mapping is removed.
- `ClaudeService.swift`: Keychain `service` identifier `"fr.louisraille.NotchBuddy"` → `"app.heyllo"`.
  This is a deliberate choice, not an oversight (see risk note below) — the alternative of
  leaving the original author's identifier baked into every saved credential is worse. Also
  rewrite the hardcoded system prompt `"You are Mochi, Louis's personal AI assistant embedded
  in the notch of his Mac."` → a generic, user-neutral Lexy prompt with no third party's name in
  it.
- `IslandStateMachine.swift` / `IslandWindowController.swift`: rename the `.coucou` enum case
  (the greeting state) to `.greeting` across all call sites — an intent-based name, not a brand
  name, so it doesn't collide with the mechanical string sweep.
- `coucou_agent` wire field (`HookServer.swift` read sites, both embedded Python relay write
  sites, `docs/AGENTS.md`): renamed to `heyllo_agent`, **no backward-compatible alias**. Heyllo
  is a freshly, independently named project — there are no existing third-party integrations
  built against it to preserve compatibility for; anyone integrating does so against Heyllo's
  own docs from day one.

**User-facing strings and error domains**
- `HookServer.swift`: 9 occurrences of `NSError(domain: "Coucou", ...)` → `"Heyllo"`.
- `AppDelegate.swift`: accessibility description strings `"Coucou"` → `"Heyllo"`.
- `SettingsView.swift`: hardcoded `~/.claude/coucou/` path strings and the App Store
  install-location label → `~/.claude/heyllo/` / `Heyllo`.

**Docs and scripts**
- Root: `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `CLAUDE.md` — rewritten for the new
  name/character, dropping Coucou/Mochi-specific content tied to removed media or old character
  art.
- `.github/ISSUE_TEMPLATE/*.md` — text updated. `.github/workflows/build.yml` and `release.yml`
  — these hardcode the folder/project/scheme path (`cd NotchBuddy && xcodegen`,
  `-project NotchBuddy/NotchBuddy.xcodeproj -scheme NotchBuddy`); update as **structural build
  input changes**, not cosmetic text, and verify CI still runs green after.
- `docs/AGENTS.md`, `docs/SPEC.md`, `docs/INTEGRATIONS.md` — rewritten for the new name, new
  paths, and the `heyllo_agent` field.
- `docs/index.html`, `docs/support.html`, `docs/privacy.html`, `docs/terms.html`,
  `docs/legal.html` — these are the shipped legal/support pages; content is **reviewed and
  rewritten**, not blindly find-replaced, since they name the old app in a compliance context.
- `scripts/release.sh`, `scripts/test-safe-links.sh`, `scripts/test-screen-geometry.sh` —
  update hardcoded paths/names (`BUILD_DIR=/tmp/coucou-release-*`, `Coucou.app`/`Coucou.zip`,
  the `NotchBuddy` folder/project/scheme references, the `--keychain-profile coucou-notary`
  name, the `--repo Louis-CFM/coucou` reference). `release.sh`'s actual notarization flow still
  depends on the user's own Apple Developer credentials (out of scope, per Scope section) —
  it's corrected for consistency but not exercised end-to-end in this pass.

No migration path is implemented for existing `~/.claude/coucou/` installs or pre-existing
Keychain entries — this is a fresh, independently-named fork, not an update to the upstream
Coucou app, so there's nothing on this machine to migrate from. (The Antigravity config
cleanup above is the one exception, since the app itself may have already written that file.)

### 6. Licensing files

- `LICENSE` (MIT): **unchanged** — the original copyright notice must be retained per the MIT
  license's own terms. This is a legal requirement, not a branding decision.
- `LICENSE-ASSETS.md`: rewritten from scratch to describe the **new** proprietary assets (the
  "Heyllo" name, the "Lexy" character design, the new icon, the new sounds) as the fork
  owner's property, with no remaining reference to the old Coucou/Mochi assets (since none of
  them ship in this fork after §4).

## Verification

1. **Allowlist-gated sweep**, not a blind zero-hit grep: `grep -ril "coucou\|mochi" .`
   (excluding `.git/` and `windows/`) must match **only** entries explicitly listed in a short
   allowlist (e.g. historical references in `CHANGELOG.md` describing past versions). Any hit
   not on the allowlist is a bug. This replaces a plain "zero hits" gate, which is both
   unachievable (it would force renaming unrelated things like `IslandStateMachine`'s `.coucou`
   case into a brand-polluted name) and insufficient (it wouldn't catch a predicate that got
   renamed to "heyllo" but should have matched both old and new, like the Antigravity key).
2. No stale `NotchBuddy.xcodeproj` remains; `xcodegen` regenerates `Heyllo.xcodeproj` cleanly
   from `Heyllo/project.yml`.
3. A **Debug** build builds and launches in Xcode under the `Heyllo` target and `app.heyllo`
   bundle ID. (Release/notarization is explicitly out of scope — see Scope.)
4. **End-to-end hook test for both build configurations** — not just "the installer writes
   files." Trigger a real Claude Code hook event (e.g. `PreToolUse`) against both the GitHub
   build (socket under `~/Library/Application Support/Heyllo/`) and the App Store build (socket
   under the new container path) and confirm a pill state change is observed in the running app.
5. **Hook reinstall/uninstall idempotency**: install hooks, reinstall, confirm no duplicate
   entry is appended; uninstall, confirm the entry is fully removed. This exercises the fixed
   self-identifying matchers from §5.
6. **Visual smoke check across all three character render sites** — not just the main pill:
   Lexy's dot-face and bowtie render in each `EyeShape` state in the island, in the greeting
   animation, and in the upload sequence, without crashing or obvious geometry glitches.
   (Exhaustive pixel-perfect review is not required for this pass.)

## Risks / open notes

- The three-renderer unification (§1) is more design work than a single-file edit — expect the
  shared `LexyGeometry` module to need its own iteration pass to look right across all three
  call sites, not just the main pill.
- Hand-drawing a convincing dot-cluster face in SwiftUI `Canvas`/`CGContext` is inherently a
  visual-design iteration task — expect a few passes on proportions, spacing, and bowtie
  placement across all `EyeShape` states.
- Renaming the Keychain service identifier means every user who previously saved API keys
  (under the old bundle ID/signature) will need to re-enter them after installing Heyllo. This
  is actually unavoidable regardless of the service-string choice, because Keychain ACL trust
  is scoped to the app's code signature, which changes with the new bundle ID anyway — but it
  should be called out explicitly in release notes so it isn't mistaken for a bug or data loss.
- Every user will also see fresh macOS Accessibility/Automation permission prompts under the
  new bundle identifier — expected, not a regression, but worth a release-note mention.
- Release/App Store signing and notarization are deferred until the user supplies their own
  Apple Developer Team ID; this spec only covers a working local Debug build.
- New sound recordings and icon artwork are separate creative deliverables (not code) — this
  spec covers wiring them in, not producing them.

## Review history

- **Rev 1** (initial): scoped the rebrand to `BotEngine.swift`'s drawing code, a basic string
  rename table, and a "zero grep hits" exit gate.
- **Rev 2** (this version): incorporated findings from a parallel architecture review and
  security review, which found (a) the character is independently drawn in three files, not
  one; (b) several runtime identifiers (Keychain service, two embedded socket-path literals,
  a published wire-protocol field, an Antigravity config key, a `UserDefaults` key, six
  hook-detection predicates across two files) are load-bearing and were missing from the
  original rename table; (c) the committed `NotchBuddy.xcodeproj`, `scripts/`, and most of
  `docs/` were missing from scope; and (d) the "zero grep hits" gate would have forced an
  incorrect rename of an `IslandStateMachine` enum case and the `coucou_agent` wire field.
  All findings are folded into the design and verification sections above.
