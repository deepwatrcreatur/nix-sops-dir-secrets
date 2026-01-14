{ lib }:
{ config, ... }:
let
  cfg = config.services.sopsDirSecrets;
  secrets = lib.mkSecretsFromDir {
    secretsDir = cfg.secretsDir;
    defaultMode = cfg.defaultMode;
    txt = cfg.txt;
    yaml = cfg.yaml;
    extraSecrets = cfg.extraSecrets;
  };

in
{
  options.services.sopsDirSecrets = {
    enable = lib.mkEnableOption "Auto-wire sops-nix secrets from a directory";

    secretsDir = lib.mkOption {
      type = lib.types.path;
      description = "Directory containing encrypted secrets (e.g. ./secrets).";
    };

    defaultMode = lib.mkOption {
      type = lib.types.str;
      default = "0400";
      description = "Default file mode for generated sops secrets (system scope).";
    };

    txt = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      suffix = lib.mkOption {
        type = lib.types.str;
        default = ".txt.enc";
      };
      format = lib.mkOption {
        type = lib.types.str;
        default = "json";
      };
      key = lib.mkOption {
        type = lib.types.str;
        default = "data";
      };
    };

    yaml = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      suffixes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          ".yaml.enc"
          ".yml.enc"
        ];
      };
      separator = lib.mkOption {
        type = lib.types.str;
        default = "__";
      };
    };

    extraSecrets = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Additional explicit sops.secrets entries merged over auto-generated ones.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config ? sops;
        message = "services.sopsDirSecrets requires sops-nix NixOS module (config.sops).";
      }
    ];

    sops.secrets = secrets;
  };
}
