_: {
  type = null;
  proxmox = {
    vm = {
      id = 202;
      enable = true;
    };
    network.interfaces = {
      net0 = {
        name = "ens18";
        macAddress = "BC:24:11:3D:39:91";
        address4 = "10.1.1.46/24";
        address6 = "auto";
      };
      net1.internal.enable = true;
    };
  };
}
