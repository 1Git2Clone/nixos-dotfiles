# AGENTS.md

Instructions for agents working in this repo.

## Hard rule: no impure evaluation

Evaluation in this repo stays pure. No `--impure` on a nix command, no
`builtins.getEnv`, no `NIXPKGS_ALLOW_UNFREE` in the environment, no
`builtins.getFlake` pointed at a local path, and no reading from outside the
store.

Impure evaluation buys one command and costs the guarantee behind it: CI
evaluates the installer with no credential and no flags, and a rebuild on one
machine is supposed to be the same rebuild as on another.

- **Pin in `flake.lock`.** A moving ref is refreshed with `nix flake update
  <input>`, not with `--override-input` at the prompt: a machine rebuilt only
  with an override sits on a revision no other machine has.
- **A dependency that wants impure evaluation is an input, not a hack.**
  `fetchTarball` becomes a flake input, the way `modules/desktop/aagl.nix`
  does it.
- **`allowUnfree` belongs in `nixpkgs.config`**, in a module
  (`modules/system.nix`), where it is pure. The environment variable route is
  an impurity, and so is reading one.
- **Secrets come from sops-nix.** A secret read with `builtins.getEnv` is part
  of the evaluation.
- **Find a derivation through the input**, `inputs.<name>.packages`, not
  through `getFlake` on a checkout on disk.
- **A dirty tree is not a revision.** Commit before rebuilding, or the machine
  and CI are not evaluating the same thing.

If a command only works with `--impure`, the fix is in the flake, not in the
flag. The bar is CI's own check, with no flags and no credentials:

```bash
nix eval --raw '.#nixosConfigurations.installer.config.system.build.isoImage.drvPath'
```

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
