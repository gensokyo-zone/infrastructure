_: {
  type = "Linux";
  access.hostName = "idp";
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
  extern.files = {
    "/etc/systemd/resolved.conf" = {
      source = ./resolved.conf;
      mode = "0644";
    };
    "/etc/NetworkManager/system-connections/ens18.nmconnection" = {
      source = ./ens18.nmconnection;
      mode = "0600";
    };
    "/etc/NetworkManager/system-connections/int.nmconnection" = {
      source = ./int.nmconnection;
      mode = "0600";
    };
  };
  exports = {
    services = {
      sshd = {
        enable = true;
        ports.public.enable = false;
      };
      freeipa.enable = true;
      ldap.enable = true;
      kerberos.enable = true;
    };
  };
}
