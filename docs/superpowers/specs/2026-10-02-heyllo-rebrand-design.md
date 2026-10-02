# Heyllo rebrand (macOS) — design spec

## Why

This repo is a fork of [Louis-CFM/coucou](https://github.com/Louis-CFM/coucou). Its source
code is MIT-licensed, but per `LICENSE-ASSETS.md`, the name "Coucou", the character "Mochi",
the app/menu-bar icon, the sounds, and the media in `docs/media/` and `design/` remain the
exclusive property of the original author and may not ship in a distributed fork. To publish
this fork under its own identity, those assets must be replaced; the underlying engineering
(state machine, hooks, integrations) is unaffected and stays.

## Scope

**In scope:** the macOS app only (currently `NotchBuddy/`), plus repo-root branding
(README, CHANGELOG, CONTRIBUTING, CLAUDE.md, GitHub issue templates and macOS-relevant
workflow text), plus removal of proprietary demo media.

**Out of scope (explicitly deferred to later work):**
- Windows/Linux (`windows/`) — code and docs untouched this pass.
- Functional improvements beyond the rebrand — separate future spec.
- New demo screenshots/GIFs/video of Lexy — needs a working build first; out of scope here.

## New identity

| Old | New |
|---|---|
| App name "Coucou" | **Heyllo** |
| Character "Mochi" | **Lexy** |
| Project folder `NotchBuddy/` | `Heyllo/` |
| Xcode target `NotchBuddy` | `Heyllo` |
| Xcode target `CoucouAppStore` | `HeylloAppStore` |
| Bundle ID `fr.louisraille.NotchBuddy` | `app.heyllo` |
| Bundle ID `fr.louisraille.Coucou` | `app.heyllo.appstore` |
| Entitlements `Coucou.entitlements` | `Heyllo.entitlements` |
| Entitlements `CoucouAppStore.entitlements` | `HeylloAppStore.entitlements` |
| Hook install dir `~/.claude/coucou/` | `~/.claude/heyllo/` |
| `MochiConst` enum (`BotEngine.swift`) | `LexyConst` |

The `nb-hook` script name predates the "Coucou" marketing name and is not a protected brand
asset — it stays as-is.

Character visual concept: a small cluster of dots forming a face (in the style of recent
minimal dot/blob marks), with a small dot-built bowtie as Lexy's one signature accessory —
cute, with a light "professional" cue. Sound set: new recordings, same 28 filenames, a
soft/professional tone rather than the original's playful chimes.

## Design

### 1. Character rendering

Extract rendering out of `BotEngine.swift` (1,503 lines — mixes state machine and drawing)
into a new, focused file: `Heyllo/Sources/App/LexyRenderer.swift`.

- `LexyRenderer` owns: the dot-cluster face geometry, the mapping from each existing
  `EyeShape` case (pill, wide, dot, line, flat, happy, closed, spiral, heart, star, tired,
  wink, cup) to a dot arrangement, and the bowtie shape.
- `BotEngine.swift` keeps its state machine as-is: `BotStateCfg`, `BadgeType`, `Particle`,
  blink/squash/gulp/slap/greet/triggerEmote/emit/update(dt:) and all timing/behavior logic.
  Its `draw(context:size:)` delegates geometry to `LexyRenderer` instead of calling its own
  `mochiPath`/`drawBody`/`drawEyes`/`drawEyeShape`.
- `BotCanvasView.swift`, `GreetingCanvasView.swift`, `UploadCanvasView.swift` are unaffected —
  they host the Canvas/TimelineView and don't define character geometry.
- Rationale: isolates 100% of the net-new visual work behind one clear interface
  (`draw(context:state:)`-shaped), without touching proven animation/timing code, and shrinks
  an oversized file per the project's file-size conventions.

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

Mechanical rename pass, verified by grep before/after each file:

- `NotchBuddy/project.yml` → move/rename to `Heyllo/project.yml`: target names, bundle
  identifiers, entitlements file references (per table above).
- `Info.plist`: `CFBundleName`, `CFBundleDisplayName`.
- Entitlements files: rename `Coucou.entitlements` → `Heyllo.entitlements`,
  `CoucouAppStore.entitlements` → `HeylloAppStore.entitlements`.
- `BotEngine.swift`: rename `MochiConst` → `LexyConst`.
- `HookServer.swift`: 9 occurrences of `NSError(domain: "Coucou", ...)` → `"Heyllo"`; hook
  install path logic updated to `~/.claude/heyllo/`.
- `AppDelegate.swift`: accessibility description strings `"Coucou"` → `"Heyllo"`.
- `SettingsView.swift`: hardcoded `~/.claude/coucou/` path strings → `~/.claude/heyllo/`.
- Root docs: `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `CLAUDE.md` — rewritten for the
  new name/character, keeping the structure but dropping Coucou/Mochi-specific content that no
  longer applies (e.g. removed media, old feature descriptions tied to the old character art).
- `.github/ISSUE_TEMPLATE/*.md`, `.github/workflows/*` — macOS-relevant text updated; Windows/
  Linux-only workflow content left alone.
- The whole `NotchBuddy/` folder is moved to `Heyllo/` as part of this pass (folder rename +
  all internal path references that depend on it, e.g. Xcode scheme files).

No migration path is implemented for existing `~/.claude/coucou/` installs — this is a fresh,
independently-named fork, not an update to the upstream Coucou app, so there's nothing to
migrate from on this machine.

### 6. Licensing files

- `LICENSE` (MIT): **unchanged** — the original copyright notice must be retained per the MIT
  license's own terms. This is a legal requirement, not a branding decision.
- `LICENSE-ASSETS.md`: rewritten from scratch to describe the **new** proprietary assets (the
  "Heyllo" name, the "Lexy" character design, the new icon, the new sounds) as the fork
  owner's property, with no remaining reference to the old Coucou/Mochi assets (since none of
  them ship in this fork after step 4).

## Verification

After the sweep is complete:
1. `grep -ril "coucou\|mochi" .` (excluding `.git/` and `windows/`) returns zero hits.
2. `xcodegen` regenerates `Heyllo.xcodeproj` without errors from the renamed `project.yml`.
3. The app builds and launches in Xcode under the new target name and bundle ID.
4. The hook installer (Settings → Install hooks) writes to `~/.claude/heyllo/nb-hook` and the
   app answers hook requests over its Unix socket as before.
5. Visual smoke check: Lexy's dot-face and bowtie render in each `EyeShape` state without
   crashing or obvious geometry glitches (exhaustive pixel-perfect review is not required for
   this pass — functional correctness of the state machine wiring is the bar).

## Risks / open notes

- Hand-drawing a convincing dot-cluster face in SwiftUI `Canvas` is inherently a visual-design
  iteration task, not a one-shot mechanical change — expect a few passes to get proportions,
  spacing, and the bowtie placement looking right across all `EyeShape` states.
- New sound recordings are a separate creative task (not code) — this spec assumes placeholder
  or externally-produced `.wav` files are dropped in; it does not cover how the audio itself
  gets produced.
- Icon artwork is likewise a separate creative deliverable; this spec covers wiring it into the
  asset catalog, not designing it.
