<div align="center">

# rumdl

**A fast Markdown linter and formatter, written in Rust.**

![GitHub Release](https://img.shields.io/github/v/release/rvben/rumdl?display_name=tag&color=%23a6a)
![GitHub License](https://img.shields.io/github/license/rvben/rumdl)

</div>

## About

rumdl (Ru(st) MarkDown Linter) checks Markdown against the markdownlint rule
set and fixes most of what it finds. It is a drop-in replacement for
markdownlint-cli in CI, pre-commit hooks and editors, and it is fast enough
that linting a large documentation tree is not something you have to think
about.

**[Upstream repository](https://github.com/rvben/rumdl)**

## Quick start

1. **Create a configuration (optional)**

   ```sh
   rumdl init
   ```

   This writes a `rumdl.toml` with the defaults spelled out. rumdl works with
   no configuration at all, so this step is optional.

2. **Lint**

   ```sh
   rumdl check .
   ```

3. **Fix what can be fixed**

   ```sh
   rumdl check --fix .
   ```

   or, with formatter-style exit codes for CI:

   ```sh
   rumdl fmt .
   ```

## Commands

```
Linting and formatting:
  check                  Lint Markdown files and print warnings/errors
  fmt                    Format files and apply fixes with formatter exit codes

Rules:
  rule                   Show information about a rule, or list all rules
  explain                Explain a rule with detailed information and examples

Configuration:
  init                   Initialize a new configuration file
  config                 Show configuration or query a specific key
  import                 Import and convert markdownlint configuration files
  schema                 Generate or check the JSON schema for rumdl.toml

Editor integration:
  server                 Start the Language Server Protocol server
  vscode                 Install the rumdl VS Code extension

Other:
  code-block-tools-docs  Generate or check the built-in code-block-tools table
  completions            Generate shell completion scripts
  clean                  Clear the cache
  version                Show version information
```

## Configuration

rumdl reads, in order of precedence, inline `--config KEY=VALUE` overrides, a
`--config <file>` path, then `.rumdl.toml` / `rumdl.toml` in the project, then
a `[tool.rumdl]` section of `pyproject.toml`.

```toml
# rumdl.toml
[global]
disable = ["MD013"]

[MD007]
indent = 4
```

Run `rumdl config` to see the effective configuration and where each value came
from, and `rumdl config get <key>` to query one setting.

Already using markdownlint? `rumdl import .markdownlint.json` converts an
existing configuration to `rumdl.toml`.

## Editor integration

`rumdl server` starts a Language Server, which gives diagnostics and
fix-on-save in any LSP-capable editor. No extra package is needed; the server
is built into this binary.

## Shell completions

This package installs bash, fish and zsh completions automatically. They are
generated with `rumdl completions <shell>`, which also supports elvish and
PowerShell if you need them.

## Documentation

- [Rule reference](https://github.com/rvben/rumdl/tree/main/docs)
- [Changelog](https://github.com/rvben/rumdl/blob/main/CHANGELOG.md)
- [Upstream repository](https://github.com/rvben/rumdl)
