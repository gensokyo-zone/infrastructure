final: prev: let
  inherit (final.lib.attrsets) mapAttrs' nameValuePair;
  subBuilders = {
    applyPatches = args:
      prev.applyPatches ({
          allowSubstitutes = true;
        }
        // args);
    writeTextFile = args:
      prev.writeTextFile ({
          allowSubstitutes = true;
        }
        // args);
    writeText = name: text: final.writeTextFile' {inherit name text;};
    writeShellScript = name: text:
      final.writeTextFile' {
        inherit name;
        executable = true;
        text = ''
          #!${final.runtimeShell}
          ${text}
        '';
        checkPhase = ''
          ${final.stdenv.shellDryRun} "$target"
        '';
      };
    writeShellScriptBin = name: text:
      final.writeTextFile' {
        inherit name;
        destination = "/bin/${name}";
        executable = true;
        text = ''
          #!${final.runtimeShell}
          ${text}
        '';
        checkPhase = ''
          ${final.stdenv.shellDryRun} "$target"
        '';
      };
    symlinkJoin = args:
      prev.symlinkJoin ({
          allowSubstitutes = true;
        }
        // args);
    linkFarm = name: entries:
      (prev.linkFarm name entries).overrideAttrs (_: {
        allowSubstitutes = true;
      });
    runCommandLocal = name: env:
      final.runCommandWith {
        stdenv = final.stdenvNoCC;
        runLocal = true;
        inherit name;
        derivationArgs =
          {
            allowSubstitutes = true;
          }
          // env;
      };
    # TODO: writeScript, writeScriptBin, runCommandWith...
  };
  subBuilders' = mapAttrs' (name: nameValuePair "${name}'") subBuilders;
in {
  inherit
    (subBuilders')
    applyPatches'
    writeTextFile'
    writeText'
    writeShellScript'
    writeShellScriptBin'
    symlinkJoin'
    linkFarm'
    runCommandLocal'
    ;
  __withSubBuilders = final // subBuilders;
}
