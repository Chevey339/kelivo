# ADR-0001: Fork Rename Kelivo → Cuplivo

**Status:** Accepted (2026-07-01)
**Deciders:** cup113

## Context

The original Kelivo project (`Chevey339/kelivo`) has been unmaintained. Submitted PRs go unreviewed. The decision was made to fork the project and rebrand as Cuplivo, a new independent application.

Key constraints:
- No need to preserve local data (restorable from backup)
- Must remain compatible with existing cloud backup format
- Focus on Windows and Android platforms
- The new app is a fork, not a replacement — original community channels (QQ groups, Discord, GitHub) should remain discoverable

## Decisions

### Package Identity

| Item | Decision | Rationale |
|------|----------|-----------|
| Dart package name | `Cuplivo` | Distinct from original; clean break |
| Android applicationId | `com.cup11.cuplivo` | Custom domain, no association with original `com.psyche` |
| iOS/macOS bundle ID | `com.cup11.cuplivo` | Consistent cross-platform |
| Version | `1.0.0+1` | Fresh start; avoids confusion with original `1.1.17` lineage |
| Default branch | `main` | Modern GitHub convention; one-line CI fix needed |

### Repository Strategy

- Work is done on the existing fork (`cup113/kelivo` → renamed to `cup113/cuplivo`)
- A dedicated `cuplivo` branch hosts all rename commits; existing `feat/*` branches and PRs to upstream are untouched
- `cup113` remote retains the original Kelivo fork; `cuplivo` branch pushes to `cup113 cuplivo:main`
- Original remote `origin → Chevey339/kelivo` kept for upstream cherry-picks

### Author & Copyright

- Installer publisher, package maintainer, and copyright fields set to `cup113` with GitHub noreply email
- Original author `Psyche` / `Chevey339` attribution preserved in:
  - README acknowledgements
  - LICENSE (AGPL-3.0 unchanged)
  - In-app GitHub links to original repo (retained as "original project" references)

### About Page & Community Links

- QQ group entries kept but **labelled as "原项目 / Original"** to avoid implying the fork maintains them
- Discord link retained
- Original website link (`kelivo.psycheas.top`) kept as-is (user may not control it)
- Sponsor page **removed** (fetches from original server, not controllable)
- Added fork-specific GitHub link pointing to `cup113/cuplivo`

### In-App Behaviors

- **Update check disabled** — original server's `update.json` would incorrectly prompt Cuplivo users to "upgrade" to original Kelivo
- **OpenRouter headers** updated to identify as `Cuplivo` with referer pointing to `cup113/cuplivo`

### What Stayed Unchanged

- AGPL-3.0 license (no author name embedded in template)
- Core data format and cloud backup protocols
- Dependency modules (`dependencies/`) — separate packages left untouched
- Generated code artifacts (`*.g.dart`, `app_localizations*.dart`) — regenerated via tooling

## Consequences

### Positive

- Clean identity separation from the now-unmaintained original
- No user confusion about which app they're running
- Existing PRs and feature branches remain undisturbed
- Minimal surface area for upstream cherry-picks (only `origin` remote kept)

### Negative

- `~700` references renamed across the codebase; git blame history on these lines is lost
- Users who installed the original Kelivo cannot be migrated via app store update (different package name = different app)
- Original `kelivo.psycheas.top` infrastructure (website, sponsor API) is outside our control — if it goes down, those links break silently

### Risks

1. **OpenRouter rate limiting / analytics** — changing `X-OpenRouter-Title` from `Kelivo` to `Cuplivo` resets any analytics history the original project had; negligibly low risk
2. **iOS/macOS provisioning** — bundle ID change requires new App Store entries and fresh provisioning profiles if ever distributed via App Store Connect
3. **Windows installer APPID** — original `AppId={{A7B8C9D0-...}}` kept; no conflict since it's a fork, but should be regenerated before public distribution

## Alternatives Considered

| Alternative | Rejected Because |
|-------------|-----------------|
| Keep package name `Kelivo`, just change display name | Would cause Dart import conflicts; partial rename worse than full |
| Squash history to a single clean commit | Loss of git blame for debugging; no benefit since the fork is open |
| Maintain separate `cup113/cuplivo` repo (deleted) | Unnecessary complexity; single fork is simpler |

## Related

- CONTEXT.md updated with Cuplivo domain terms
- `.github/workflows/pr-check.yml` trigger branch changed from `master` to `main`
