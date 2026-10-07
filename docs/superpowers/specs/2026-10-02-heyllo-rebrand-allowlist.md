# Heyllo rebrand — intentional "coucou"/"mochi" occurrences

Per the verification gate in docs/superpowers/specs/2026-10-02-heyllo-rebrand-design.md,
`grep -ril "coucou|mochi"` (excluding .git/ and windows/) should match only the entries below.
Any other match is a bug.

- `CHANGELOG.md` — historical changelog entries describing past releases under the old name.
- `LICENSE-ASSETS.md` — one sentence crediting "the same courtesy this project extended to the
  original Coucou/Mochi project it was forked from"; a deliberate historical attribution, not a
  missed rename (the plan's own Task 16 Step 1 content prescribes this exact sentence).
- `CLAUDE.md` — describes `windows/`'s real, unrenamed `coucou-hook` relay binary (Windows/Linux
  is out of scope for this rebrand).
- `docs/superpowers/specs/2026-10-02-heyllo-rebrand-design.md` — describes the rename itself.
- `docs/superpowers/plans/2026-10-02-heyllo-rebrand.md` — this plan, same reason.
- `docs/superpowers/specs/2026-10-02-heyllo-rebrand-allowlist.md` — this file.
- `Heyllo/Sources/App/LexyGeometry.swift` — two comments explaining the rename lineage
  ("renamed from MochiConst, same values"; "matching how the original BotEngine.mochiPath/
  GreetingCanvasView.mochiPath callers already work"). Informational, reviewed, not pollution.
- `Heyllo/Sources/App/HookServer.swift` — `root.removeValue(forKey: "coucou")` in
  `withoutAgyHooks()`, which deliberately removes both the old and new Antigravity config keys
  so a pre-rebrand install's orphaned entry is cleaned up (see Task 9 Step 5 / spec §5).
- `docs/AGENTS.md`, `docs/privacy.html`, `docs/support.html` — real, unrenamed Windows/Linux
  field names (`coucou_agent`), paths (`%APPDATA%\Coucou`, `~/.config/coucou`, etc.) and package
  names (`sudo apt remove coucou`) for the untouched `windows/` relay and app.
- `docs/index.html`, `docs/support.html`, `docs/terms.html`, `docs/legal.html`, `scripts/release.sh`
  — GitHub repository URLs, contact emails and publisher/rights-holder names specific to the
  original author, each marked with an adjacent `TODO(heyllo)` comment rather than guessed at.
- `docs/SPEC.md` — two uses of "coucou" as a French idiom for a waving/peekaboo greeting gesture
  (`faire coucou`), unrelated to the brand name.
- `.github/workflows/windows.yml`, `.github/workflows/linux.yml` — Windows/Linux release
  workflows, out of scope; their `Coucou-*`/`coucou-hook` artifact and binary names describe the
  real, currently-unrenamed build outputs.
