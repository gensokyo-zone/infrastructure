{pkgs, ...}: {
  environment.systemPackages = [
    pkgs.buildPackages.rxvt-unicode-unwrapped.terminfo
  ];
}
