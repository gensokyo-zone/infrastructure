_: {
  type = "Linux";
  proxmox = {
    vm = {
      id = 203;
      enable = true;
    };
    network.interfaces = {
      net0 = {
        name = "ens18";
        macAddress = "BC:24:11:33:19:04";
        address4 = "dhcp";
        address6 = "auto";
      };
    };
  };
}
