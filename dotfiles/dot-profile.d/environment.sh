#!/bin/sh
# Environment secrets — one sops-rendered env file, sourced into every shell.
#
# modules/sops.nix builds it from the `llm:` section of secrets/secrets.yaml,
# one VAR=value line per provider, under the standard names (OPENROUTER_API_KEY,
# OPENCODE_API_KEY, ...). Shell env is the whole registration: opencode,
# claude-code and the MCP servers all read those names off their environment.
#
# `set -a` exports whatever the file assigns without naming any of it here, so
# adding a provider stays a two-line change in secrets.yaml and sops.nix.
#
# Guarded: the file is absent on a host without sops (hutao-vm, or this tree
# stowed anywhere else), and a missing one must not break login. It replaces a
# row of `secret-tool` lookups against a keyring that holds none of these.
LLM_ENV=/run/secrets/rendered/llm.env

if [ -r "$LLM_ENV" ]; then
  set -a
  . "$LLM_ENV"
  set +a
fi

unset LLM_ENV
