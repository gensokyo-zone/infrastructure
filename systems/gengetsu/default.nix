_: {
  imports = [
  ];
  arch = "x86_64";
  type = "NixOS";
  modules = [
    ./nixos.nix
  ];
  deploy.hostname = "10.1.1.204";
  deploy.sshOpts = [];
  #exports = {
  #services = {
  #};
  #};
  network.networks = {
    local = {
      address4 = "10.1.1.204";
    };
  };
}
