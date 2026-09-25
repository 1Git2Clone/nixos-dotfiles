# CI and pages

Two workflows on the Forgejo instance, and a CI-only copy on the GitHub mirror.

| Workflow                       | Runs on                         | Does                                                    |
| ------------------------------ | ------------------------------- | ------------------------------------------------------- |
| `.forgejo/workflows/ci.yml`    | pushes to `main`, pull requests | pre-commit, gitleaks over full history, installer eval  |
| `.forgejo/workflows/pages.yml` | pushes to `main`                | builds this book and uploads it as the `pages` artifact |
| `.github/workflows/ci.yml`     | the GitHub mirror               | the same checks as `ci.yml`, on GitHub's runners        |

## CI

The checks are `.pre-commit-config.yaml`, the same file the local commit hook
runs, so a green CI means a clean `pre-commit run --all-files` and vice versa:

```bash
nix develop -c pre-commit run --all-files
```

gitleaks runs separately over the **whole history**, which is why checkout
fetches everything: against a shallow clone it would scan one commit and report
clean.

The evaluate job evaluates **only the installer**. The real machines pull
their cursor theme from the private `third-party-assets` repo, and evaluating
them would mean handing a runner a credential for it. They are rebuilt on the
machines themselves several times a day, which is a stronger check than an
eval.

Both Forgejo workflows run on the `nix-node` label, an image with both nix and
node, declared in the vps repo's `modules/runner/ci-image.nix`. Node is what
lets `uses:` actions run at all.

## Pages

This book is built on every push to `main` and published at
<https://pages.hu-tao.dev/hutao/nixos-dotfiles/docs/>.

The workflow publishes nothing itself. It uploads an artifact named `pages`,
and the VPS's `modules/pages-pull.nix` discovers every **public** repo holding
one and unpacks it, every few minutes. There is no list on the VPS to add this
repo to; uploading the artifact is what makes it a pages repo. The artifact's
layout is the URL below `/<owner>/<repo>/`, which is why the book is staged
under `_site/docs/`. The pull side is documented in the vps handbook's
[Pages](https://pages.hu-tao.dev/hutao/vps/docs/operations/pages.html) chapter.

To write or preview the book locally:

```bash
nix run .#docs          # mdbook-mermaid install, then mdbook serve with live reload
```

The pages workflow only runs on `main`, so the book is also built by a
pre-commit hook, which means on every commit that touches `docs/` and in CI on
every pull request. It fails on anything mdbook rejects, including a
`SUMMARY.md` chapter with no file (`book.toml` sets `create-missing = false`).
It does **not** check links inside a page: a dead one builds cleanly.
