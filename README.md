# nix-sops-dir-secrets

Auto-wire `sops-nix` secrets from a directory based on filename conventions.

This is useful when you want to manage secrets by simply adding/removing encrypted files in a folder, without having to edit Nix code for each new secret.

## Configuration Model

This flake does **not** try to auto-discover your repo layout. You must point it at a directory via `services.sopsDirSecrets.secretsDir`.

Reason: Nix path resolution is lexical (relative paths resolve relative to the module file), and a generic flake cannot reliably guess where *your* `secrets/` directories live.

In practice, you still get the “just add/remove files” workflow by setting:
- NixOS/system secrets: `services.sopsDirSecrets.secretsDir = ./secrets;` (in the host/module that sits next to your system `secrets/` directory)
- Home Manager/user secrets: `services.sopsDirSecrets.secretsDir = ./secrets;` (in the user module that sits next to the user’s `secrets/` directory)

## Conventions

### Simple one-value secrets (`*.txt.enc`)

If a file matches `*.txt.enc`, it is assumed to be a SOPS-encrypted **JSON** document with a top-level `data` key.

- Filename: `github-token.txt.enc`
- Secret name: `github-token`
- Decryption: `format = "json"`, `key = "data"`

Name rules:
- Strip the suffix `.txt.enc`
- Lowercase
- Convert `.`, `_`, and spaces to `-`

### YAML secrets with key extraction (`<name>__<key>.yaml.enc`)

If a file matches `<name>__<key>.yaml.enc` or `<name>__<key>.yml.enc`, it is assumed to be a SOPS-encrypted **YAML** file and the module extracts the YAML key named `<key>`.

Example:
- Filename: `atuin__atuin_key.yaml.enc`
- Secret name: `atuin`
- Extracted key: `atuin_key`
- Decryption: `format = "yaml"`, `key = "atuin_key"`

## Usage

### Home Manager

Add the flake input and import the module alongside `sops-nix`:

```nix
{
  inputs = {
    sops-nix.url = "github:Mic92/sops-nix";
    nix-sops-dir-secrets.url = "github:deepwatrcreatur/nix-sops-dir-secrets";
  };

  outputs = { inputs, ... }: {
    homeConfigurations.<name> = ... {
      modules = [
        inputs.sops-nix.homeManagerModules.sops
        inputs.nix-sops-dir-secrets.homeManagerModules.default

        {
          services.sopsDirSecrets = {
            enable = true;
            secretsDir = ./secrets;

            # optional
            defaultMode = "0600";
            txt.key = "data";
            yaml.separator = "__";

            # for special cases
            extraSecrets = {
              "oauth_creds" = {
                sopsFile = "${toString ./secrets}/oauth_creds.json.enc";
                format = "binary";
                path = "${config.home.homeDirectory}/.gemini/oauth_creds.json";
                mode = "0600";
              };
            };
          };
        }
      ];
    };
  };
}
```

### NixOS

Import the module alongside `sops-nix` NixOS module:

```nix
{
  imports = [
    inputs.sops-nix.nixosModules.sops
    inputs.nix-sops-dir-secrets.nixosModules.default
  ];

  services.sopsDirSecrets = {
    enable = true;
    secretsDir = ./secrets;
    defaultMode = "0400";
  };
}
```

## Options

### Required

- `services.sopsDirSecrets.secretsDir`: directory containing encrypted secrets

### Defaults

Home Manager module defaults:
- `defaultMode = "0600"`

NixOS module defaults:
- `defaultMode = "0400"`

Filename convention defaults:
- `txt.enable = true`, `txt.suffix = ".txt.enc"`, `txt.format = "json"`, `txt.key = "data"`
- `yaml.enable = true`, `yaml.suffixes = [ ".yaml.enc" ".yml.enc" ]`, `yaml.separator = "__"`

### Customization

- `services.sopsDirSecrets.txt.*`: configure `*.txt.enc` handling (suffix/format/key)
- `services.sopsDirSecrets.yaml.*`: configure `<name>__<key>.yaml.enc` handling
- `services.sopsDirSecrets.extraSecrets`: explicit overrides for special cases (binary files, custom paths, custom modes)

## Library

The flake also exports `lib.mkSecretsFromDir` so you can use the logic directly:

```nix
inputs.nix-sops-dir-secrets.lib.mkSecretsFromDir { secretsDir = ./secrets; }
```
