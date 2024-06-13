_: {
  type = "Linux";
  proxmox = {
    vm = {
      id = 203;
      enable = true;
    };
    network.interfaces = {
      net0 = {
        name = "eth0";
        macAddress = "BC:24:11:33:19:04";
        address4 = "10.1.1.43";
        address6 = "auto";
      };
    };
  };
  extern.files = {
    "/etc/sysconfig/network-scripts/ifcfg-eth0" = {
      source = ./ifcfg-eth0;
    };
    "/etc/asterisk/prometheus.conf" = {
      source = ./asterisk-prometheus.conf;
      owner = "asterisk";
      group = "asterisk";
    };
    "/root/.ssh/authorized_keys" = {
      source = ../reisen/root.authorized_keys;
    };
  };
  exports = {
    services = {
      sshd = {
        enable = true;
        ports.public.enable = false;
      };
      freepbx.enable = true;
    };
  };
}
