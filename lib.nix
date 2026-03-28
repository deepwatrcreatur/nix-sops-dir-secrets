{ lib }:
let
  # Transform a filename base into a secret name.
  defaultNameFromBase = base: lib.toLower (lib.replaceStrings [ "." "_" " " ] [ "-" "-" "-" ] base);

  yamlParts =
    separator: suffixes: file:
    let
      matchingSuffix = lib.findFirst (suffix: lib.hasSuffix suffix file) null suffixes;
    in
    if matchingSuffix == null then
      null
    else
      let
        withoutSuffix = lib.removeSuffix matchingSuffix file;
        parts = lib.splitString separator withoutSuffix;
      in
      if builtins.length parts < 2 then
        null
      else
        let
          keyName = lib.last parts;
          base = lib.concatStringsSep separator (lib.init parts);
        in
        if base == "" || keyName == "" then
          null
        else
          {
            inherit base keyName;
          };

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

      yamlFiles =
        if yaml.enable then
          lib.filter (
            f: isRegular f && yamlParts yaml.separator yaml.suffixes f != null
          ) files
        else
          [ ];

      mkYaml =
        file:
        let
          parts = yamlParts yaml.separator yaml.suffixes file;
          base = parts.base;
          keyName = parts.keyName;
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

      generatedSecrets = map mkTxt txtFiles ++ map mkYaml yamlFiles;
      duplicateNames = lib.attrNames (lib.filterAttrs (_: values: builtins.length values > 1) (lib.groupBy (entry: entry.name) generatedSecrets));
      auto =
        if duplicateNames != [ ] then
          throw "nix-sops-dir-secrets: duplicate generated secret names: ${lib.concatStringsSep ", " duplicateNames}"
        else
          lib.listToAttrs generatedSecrets;

    in
    auto // extraSecrets;

in
{
  inherit mkSecretsFromDir;
}
