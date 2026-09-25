# AGENTS.md

Instructions for agents working in this repo.

## Keep the docs in step

At the end of every task, before calling it done, check the docs against what
you changed and update them in the same branch:

- **`docs/src/`**, the handbook. Find the chapter that describes what you
  touched (`docs/src/SUMMARY.md` lists them) and make it true again: a new
  module, option, secret, host, command or gotcha belongs somewhere in it. A
  new topic gets its own page, added to `SUMMARY.md`.
- **`README.md`**, the short version: the repo tree, the chapter table and the
  quick-start commands.
- **Comments that point at the docs**, like `install.sh`'s and
  `secrets/secrets.example.yaml`'s, when a section they name moves or goes.

If nothing needed changing, say so in your summary rather than skipping the
check. State only what the code does: verify a claim against the module before
writing it, and date a gotcha that was learned the hard way.

Check the result with `nix develop -c pre-commit run --all-files`, which builds
the book. It fails on a `SUMMARY.md` chapter with no file, not on a dead link
inside a page, so follow any links you add or move by hand.
