{config, ...}: {
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    interactiveShellInit = ''
      setopt autocd
      setopt HIST_IGNORE_DUPS
      setopt HIST_IGNORE_SPACE
      HISTORY_IGNORE="(*^C*|:*|/*|~*|.(/*|./*|.)|(sudo |)(ls|cd)( *|))"
    '';
    shellAliases = {
      sys = "systemctl";
      sysu = "systemctl --user";
      log = "journalctl";
      logu = "journalctl --user";

      cp = "cp --reflink=auto --sparse=auto";
    };
  };
  programs.bash = {
    interactiveShellInit = ''
      HISTIGNORE="[bf]g:exit: *:*^C*"
    '';
  };
}
