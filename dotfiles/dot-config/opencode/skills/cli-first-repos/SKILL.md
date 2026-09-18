---
name: cli-first-repos
description: Fetch repository data via CLI first (fj for Forgejo, gh for GitHub). Use this skill whenever the user asks about issues, pull requests, repos, releases, CI runs, or any data living on Forgejo or GitHub — even if they do not mention fj, gh, or a skill explicitly. Never reach for webfetch first for these hosts.
---

# CLI-first repos

Prefer dedicated CLI tools over webfetch when reading data from
Forgejo or GitHub. CLIs return structured data, respect auth, and avoid
rate limits and markdown-mangled HTML.

## Rules

- Forgejo (`git.hu-tao.dev`, or any Forgejo host): use `fj`.
  - Issues: `fj issue search`, `fj issue view <number>`
  - Pull requests: `fj pr search`, `fj pr view <number>`, `fj pr status`
  - Repos and misc: `fj repo view`, `fj release --help`, `fj user --help`
  - Run from inside the repo checkout so `-R`/`-C` resolve automatically.
    Otherwise pass `-R <remote>` or `-C <path>`.
- GitHub: use `gh` (`gh issue`, `gh pr`, `gh repo`, `gh release`, `gh run`).
- Do not use webfetch (or raw API scraping) as the first resort for
  either host. Webfetch HTML pages render poorly and burn rate limits.

## Why

Webfetch against Forgejo/GitHub returns JS-shell pages or
markdown-ified HTML that loses tables, checkboxes, and metadata, and
anonymous fetches eat into rate limits. `fj`/`gh` are authenticated,
return full bodies (including Renovate dashboards and release notes),
and support search, filter, and view natively.

## Fallback

If the CLI fails, retry once after checking auth
(`fj whoami`, `gh auth status`). If it still fails, fall back to a
single webfetch/API read, then report the CLI error verbatim alongside
whatever the fallback returned. Do not loop fallbacks.

## Examples

**Example 1 — open issues:**
User: "what's today's issue?"
Do: `fj issue search --state open`, then `fj issue view <n>` for detail.
Don't: webfetch the `/issues` HTML page.

**Example 2 — Renovate PRs:**
User: "renovate told me there's a new prettier update"
Do: `fj pr search --state open`, then `fj pr view <n>`.
Don't: webfetch the PR list page.

**Example 3 — GitHub data:**
User: "check the upstream releases"
Do: `gh release list`, `gh release view <tag>`.
Don't: webfetch github.com release pages first.
