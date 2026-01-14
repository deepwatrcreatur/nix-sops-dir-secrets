{ lib }:
let
  # Transform a filename base into a secret name.
  defaultNameFromBase = base: lib.toLower (lib.replaceStrings [ "." "_" " " ] [ "-" "-" "-" ] base);

  mkSecretsFromDir =
    {
      secretsDir,
      defaultMode ? "0600",
      txt ? {
        enable = true;
        suffix = ".txt.enc";
        format = "json";
        key = "data";
      },
      yaml ? {
        enable = true;
        suffixes = [
          ".yaml.enc"
          ".yml.enc"
        ];
        separator = "__";
      },
      nameFromBase ? defaultNameFromBase,
      extraSecrets ? { },
    }:
    let
      secretsDirPath =
        if builtins.isPath secretsDir then secretsDir else builtins.path { path = secretsDir; };

      entries = builtins.readDir secretsDirPath;
      files = builtins.attrNames entries;
      isRegular = f: entries.${f} == "regular";

      toSopsFile = f: "${toString secretsDirPath}/${f}";

      txtFiles =
        if txt.enable then lib.filter (f: isRegular f && lib.hasSuffix txt.suffix f) files else [ ];

      mkTxt =
        file:
        let
          base = lib.removeSuffix txt.suffix file;
          name = nameFromBase base;
        in
        {
          inherit name;
          value = {
            sopsFile = toSopsFile file;
            format = txt.format;
            key = txt.key;
            mode = defaultMode;
          };
        };

      yamlKeyMatch =
        file:
        # `<name>__<key>.yaml.enc` or `.yml.enc`
        builtins.match "^(.*)${yaml.separator}([^/]+)\\.(yaml|yml)\\.enc$" file;

      yamlFiles =
        if yaml.enable then
          lib.filter (
            f: isRegular f && builtins.any (s: lib.hasSuffix s f) yaml.suffixes && yamlKeyMatch f != null
          ) files
        else
          [ ];

      mkYaml =
        file:
        let
          m = yamlKeyMatch file;
          base = builtins.elemAt m 0;
          keyName = builtins.elemAt m 1;
          name = nameFromBase base;
        in
        {
          inherit name;
          value = {
            sopsFile = toSopsFile file;
            format = "yaml";
            key = keyName;
            mode = defaultMode;
          };
        };

      auto = lib.listToAttrs (map mkTxt txtFiles) // lib.listToAttrs (map mkYaml yamlFiles);

    in
    auto // extraSecrets;

in
{
  inherit mkSecretsFromDir;
}
