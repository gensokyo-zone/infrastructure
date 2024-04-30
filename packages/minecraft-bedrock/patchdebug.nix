{ lib, python3, writeTextFile }: let
  # https://github.com/minecraft-linux/server-modloader/tree/master?tab=readme-ov-file#getting-mods-to-work-on-newer-versions-116
  inherit (lib.meta) getExe;
  python = python3.withPackages (p: [ p.lief ]);
  script = ''
    import lief
    import sys

    lib_symbols = lief.parse(sys.argv[1])
    for s in filter(lambda e: e.exported, lib_symbols.static_symbols):
        lib_symbols.add_dynamic_symbol(s)
    lib_symbols.write(sys.argv[2])
  '';
  name = "minecraft-bedrock-server-patchdebug";
in writeTextFile {
  name = "${name}.py";
  destination = "/bin/${name}";
  executable = true;
  text = ''
    #!${getExe python}
    ${script}
  '';
  meta.mainProgram = name;
}
