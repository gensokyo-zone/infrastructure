{
  meta,
  ...
}: {
  imports = with meta; [
    nixos.reisen-ct
  ];

  # allow proxmox to provide us with our hostname
  environment.etc.hostname.enable = false;
  services.avahi.hostName = "";

  system.stateVersion = "23.11";
}
