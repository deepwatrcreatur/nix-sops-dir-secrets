# Improvements

## Summary

`nix-sops-dir-secrets` is small and readable, but it currently leans on convention without much validation or test coverage. The highest-value improvements are to make filename parsing safer, fail loudly on ambiguous input, and add lightweight evaluation checks so future refactors do not regress behavior.

## High-priority improvements

### 1. Fix custom YAML suffix parsing

Status: implemented locally in a follow-up PR.

The library exposes `yaml.suffixes`, but the parser was still hardcoded to `.yaml.enc` and `.yml.enc` when extracting the secret name and key. That means custom suffixes could appear configurable while failing to generate secrets.

Why it matters:
- A documented customization path did not actually work end-to-end.
- The failure mode is confusing because matching and parsing used different rules.

Recommended approach:
- Parse YAML filenames from the configured suffix list rather than from a hardcoded regex.

### 2. Fail on duplicate generated secret names

Status: implemented locally in a follow-up PR.

Multiple files can normalize to the same secret name. Examples:
- `github_token.txt.enc` and `github-token.txt.enc`
- `atuin__key.yaml.enc` and `atuin.txt.enc`

Today, those collisions overwrite silently during `listToAttrs`.

Why it matters:
- Secret selection becomes order-dependent.
- A user can lose a secret binding without any visible error.

Recommended approach:
- Group generated entries by name before converting to attrs.
- Throw with the colliding secret names if any duplicates are found.

## Medium-priority improvements

### 3. Add flake checks with fixture coverage

The repo has no automated checks yet. A small `checks` suite would protect the filename contract.

Useful cases:
- standard `*.txt.enc` mapping
- standard YAML key extraction
- custom `yaml.suffixes`
- duplicate-name failure
- `extraSecrets` overriding auto-generated entries

### 4. Tighten module option types

`extraSecrets` is currently typed as a loose `attrs`. That keeps the module flexible, but it also pushes errors later into `sops-nix`.

Recommended approach:
- Either document the intended `sops.secrets` shape more explicitly, or
- move to a typed submodule if this flake grows further.

### 5. Add example fixtures

The README explains the model well, but real example trees would make usage and conventions easier to confirm quickly.

Useful additions:
- one NixOS example
- one Home Manager example
- one custom suffix example

## Lower-priority improvements

### 6. Expose more validation around filename conventions

Potential checks:
- reject empty `yaml.separator`
- reject filenames with empty base or key segments
- optionally warn when files in the directory are ignored

### 7. Consider an explicit collision policy

Right now the safest policy is to error. If users later need controlled overrides, that should be an explicit option rather than accidental attr overwrite.

## Recommended sequencing

1. Ship parsing and collision fixes.
2. Add checks with small fixtures.
3. Improve examples and option typing once behavior is locked down.
