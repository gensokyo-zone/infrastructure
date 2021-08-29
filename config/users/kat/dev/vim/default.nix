{ config, pkgs, ... }:

let cocvim = pkgs.callPackage
  ({ stdenv, elinks, nodejs }: stdenv.mkDerivation {
    name = "coc.vim";
    src = ./coc.vim;
    inherit nodejs;
    buildInputs = [
      nodejs
    ];
    phases = [ "buildPhase" ];
    buildPhase = ''
      substituteAll $src $out
    '';
  })
  { };
in
{
  programs.neovim = {
    extraConfig = ''
      source ${cocvim}
    '';
    plugins = with pkgs.vimPlugins; [
      coc-yaml
      coc-git
      coc-css
      coc-html
      coc-nvim
      coc-rust-analyzer
      coc-yank
      coc-python
      coc-json
      coc-fzf
    ];
    coc = {
      enable = true;
      settings = {
        "rust.rustfmt_path" = "${pkgs.rustfmt}/bin/rustfmt";
        "rust-analyzer.serverPath" = "rust-analyzer";
        "rust-analyzer.updates.prompt" = false;
        "rust-analyzer.notifications.cargoTomlNotFound" = false;
        "rust-analyzer.notifications.workspaceLoaded" = false;
        "rust-analyzer.procMacro.enable" = true;
        "rust-analyzer.cargo.loadOutDirsFromCheck" = true;
        "rust-analyzer.cargo-watch.enable" = true;
        "rust-analyzer.completion.addCallParenthesis" = false; # consider using this?
        "rust-analyzer.hoverActions.linksInHover" = true;
        "rust-analyzer.diagnostics.disabled" = [
          "inactive-code" # it has strange cfg support..?
        ];
      };
    };
  };
}