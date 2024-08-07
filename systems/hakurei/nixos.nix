{
  config,
  meta,
  lib,
  access,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
  inherit (config.services) nginx syncplay;
  inherit (nginx) virtualHosts;
  hassVouch = false;
in {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.sops
    nixos.base
    nixos.reisen-ct
    nixos.kyuuto
    nixos.steam.account-switch
    nixos.steam.beatsaber
    nixos.tailscale
    nixos.ipa
    nixos.cloudflared
    nixos.systemd2mqtt
    nixos.ddclient
    nixos.acme
    nixos.nginx
    nixos.vouch
    nixos.access.nginx
    nixos.access.global
    nixos.access.mosquitto
    nixos.access.gensokyo
    nixos.access.keycloak
    nixos.access.vaultwarden
    nixos.access.vouch
    nixos.access.freeipa
    nixos.access.freepbx
    nixos.access.unifi
    nixos.access.gatus
    nixos.access.prometheus
    nixos.access.grafana
    nixos.access.loki
    nixos.access.kitchencam
    nixos.access.fluidd
    nixos.access.openwebrx
    nixos.access.deluge
    nixos.access.home-assistant
    nixos.access.zigbee2mqtt
    nixos.access.grocy
    nixos.access.barcodebuddy
    nixos.access.proxmox
    nixos.access.plex
    nixos.access.invidious
    nixos.wake-chen
    nixos.samba
    nixos.syncplay
    ./reisen-ssh.nix
  ];

  sops.secrets.cloudflared-tunnel-hakurei = {
    owner = config.services.cloudflared.user;
  };

  services.cloudflared = let
    tunnelId = "964121e3-b3a9-4cc1-8480-954c4728b604";
  in {
    tunnels.${tunnelId} = {
      default = "http_status:404";
      credentialsFile = config.sops.secrets.cloudflared-tunnel-hakurei.path;
      ingress = mkMerge [
        (virtualHosts.freeipa'web.proxied.cloudflared.getIngress {})
        (virtualHosts.freeipa'cockpit.proxied.cloudflared.getIngress {})
        (virtualHosts.prox.proxied.cloudflared.getIngress {})
        (virtualHosts.gensokyoZone.proxied.cloudflared.getIngress {})
      ];
    };
  };

  # configure a secondary vouch instance for local clients, but don't use it by default
  services.vouch-proxy = {
    authUrl = "https://${virtualHosts.keycloak'local.serverName}/realms/${config.networking.domain}";
    domain = "login.local.${config.networking.domain}";
    settings.cookie.domain = "local.${config.networking.domain}";
  };

  security.acme.certs = {
    hakurei = {
      inherit (nginx) group;
      domain = config.networking.fqdn;
      extraDomainNames = [
        access.hostnameForNetwork.local
        access.hostnameForNetwork.int
        (mkIf config.services.tailscale.enable access.hostnameForNetwork.tail)
      ];
    };
    mosquitto = {
      inherit (nginx) group;
      domain = "mqtt.${config.networking.domain}";
      extraDomainNames = [
        "mqtt.local.${config.networking.domain}"
        "mqtt.int.${config.networking.domain}"
        (mkIf config.services.tailscale.enable "mqtt.tail.${config.networking.domain}")
      ];
    };
    samba = {
      domain = "smb.${config.networking.domain}";
      extraDomainNames = [
        "smb.local.${config.networking.domain}"
        "smb.int.${config.networking.domain}"
        (mkIf config.services.tailscale.enable "smb.tail.${config.networking.domain}")
      ];
    };
    syncplay = {
      inherit (syncplay) group;
      domain = "syncplay.${config.networking.domain}";
      extraDomainNames = [
        "syncplay.local.${config.networking.domain}"
        "syncplay.int.${config.networking.domain}"
        (mkIf config.services.tailscale.enable "syncplay.tail.${config.networking.domain}")
      ];
    };
    sso = {
      inherit (nginx) group;
      domain = virtualHosts.keycloak.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.keycloak.otherServerNames
        virtualHosts.keycloak'local.allServerNames
      ];
    };
    bw = {
      inherit (nginx) group;
      domain = virtualHosts.vaultwarden.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.vaultwarden.otherServerNames
        virtualHosts.vaultwarden'local.allServerNames
      ];
    };
    home = {
      inherit (nginx) group;
      domain = virtualHosts.home-assistant.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.home-assistant.otherServerNames
        virtualHosts.home-assistant'local.allServerNames
      ];
    };
    z2m = {
      inherit (nginx) group;
      domain = virtualHosts.zigbee2mqtt.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.zigbee2mqtt.otherServerNames
        virtualHosts.zigbee2mqtt'local.allServerNames
      ];
    };
    grocy = {
      inherit (nginx) group;
      domain = virtualHosts.grocy.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.grocy.otherServerNames
        virtualHosts.grocy'local.allServerNames
      ];
    };
    bbuddy = {
      inherit (nginx) group;
      domain = virtualHosts.barcodebuddy.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.barcodebuddy.otherServerNames
        virtualHosts.barcodebuddy'local.allServerNames
      ];
    };
    login = let
      inherit (lib.lists) head tail optional optionals;
      domains =
        optional virtualHosts.vouch.enable virtualHosts.vouch.serverName
        ++ virtualHosts.vouch'local.allServerNames
        ++ optionals virtualHosts.vouch.enable virtualHosts.vouch.otherServerNames
        ++ optionals virtualHosts.vouch'tail.enable virtualHosts.vouch'tail.allServerNames;
    in {
      inherit (nginx) group;
      domain = head domains;
      extraDomainNames = tail domains;
    };
    unifi = {
      inherit (nginx) group;
      domain = virtualHosts.unifi.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.unifi.otherServerNames
        virtualHosts.unifi'local.allServerNames
      ];
    };
    status = {
      inherit (nginx) group;
      domain = virtualHosts.gatus.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.gatus.otherServerNames
        virtualHosts.gatus'local.allServerNames
      ];
    };
    prometheus = {
      inherit (nginx) group;
      domain = virtualHosts.prometheus.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.prometheus.otherServerNames
        virtualHosts.prometheus'local.allServerNames
      ];
    };
    mon = {
      inherit (nginx) group;
      domain = virtualHosts.grafana.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.grafana.otherServerNames
        virtualHosts.grafana'local.allServerNames
      ];
    };
    logs = {
      inherit (nginx) group;
      domain = virtualHosts.loki.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.loki.otherServerNames
        virtualHosts.loki'local.allServerNames
      ];
    };
    idp = {
      inherit (nginx) group;
      domain = virtualHosts.freeipa.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.freeipa.otherServerNames
        virtualHosts.freeipa'web.allServerNames
        virtualHosts.freeipa'web'local.allServerNames
        virtualHosts.freeipa'cockpit.allServerNames
        virtualHosts.freeipa'cockpit'local.allServerNames
        virtualHosts.freeipa'ldap.allServerNames
        virtualHosts.freeipa'ldap'local.allServerNames
        (mkIf virtualHosts.freeipa'ldap'tail.enable virtualHosts.freeipa'ldap'tail.allServerNames)
      ];
    };
    pbx = {
      inherit (nginx) group;
      domain = virtualHosts.freepbx.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.freepbx.otherServerNames
        virtualHosts.freepbx'local.allServerNames
      ];
    };
    prox = {
      inherit (nginx) group;
      domain = virtualHosts.prox.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.prox.otherServerNames
        virtualHosts.prox'local.allServerNames
        (mkIf virtualHosts.prox'tail.enable virtualHosts.prox'tail.allServerNames)
      ];
    };
    plex = {
      inherit (nginx) group;
      domain = virtualHosts.plex.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.plex.otherServerNames
        virtualHosts.plex'local.allServerNames
      ];
    };
    kitchen = {
      inherit (nginx) group;
      domain = virtualHosts.kitchencam.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.kitchencam.otherServerNames
        virtualHosts.kitchencam'local.allServerNames
      ];
    };
    print = {
      inherit (nginx) group;
      domain = virtualHosts.fluidd.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.fluidd.otherServerNames
        virtualHosts.fluidd'local.allServerNames
      ];
    };
    webrx = {
      inherit (nginx) group;
      domain = virtualHosts.openwebrx.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.openwebrx.otherServerNames
        virtualHosts.openwebrx'local.allServerNames
      ];
    };
    deluge = {
      inherit (nginx) group;
      domain = virtualHosts.deluge.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.deluge.otherServerNames
        virtualHosts.deluge'local.allServerNames
      ];
    };
    yt = {
      inherit (nginx) group;
      domain = virtualHosts.invidious.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.invidious.otherServerNames
        virtualHosts.invidious'local.allServerNames
      ];
    };
  };

  services.nginx = {
    proxied.enable = true;
    vouch.enable = true;
    upstreams' = {
      vouch'auth.servers.local.enable = false;
      vouch'auth'local.servers.local.enable = true;
      tei'nginx'proxied.servers.nginx.accessService = {
        # TODO: host exports
        system = "tei";
        name = "nginx";
        port = "proxied";
      };
    };
    stream.servers = {
      mosquitto.ssl.cert.name = "mosquitto";
    };
    virtualHosts = {
      fallback.ssl.cert.name = "hakurei";
      gensokyoZone.proxied.enable = "cloudflared";
      freeipa = {
        ssl.cert.enable = true;
      };
      freeipa'web.proxied.enable = "cloudflared";
      freeipa'cockpit.proxied.enable = "cloudflared";
      keycloak = {
        # we're not the real sso record-holder, so don't respond globally..
        local.denyGlobal = true;
        ssl.cert.enable = true;
      };
      vaultwarden = {
        # we're not the real bw record-holder, so don't respond globally..
        local.denyGlobal = true;
        ssl.cert.enable = true;
      };
      vouch = {
        ssl.cert.enable = true;
      };
      vouch'local = {
        # we're not running another for tailscale sorry...
        name.includeTailscale = true;
      };
      unifi = {
        # we're not the real unifi record-holder, so don't respond globally..
        local.denyGlobal = true;
        ssl.cert.enable = true;
      };
      gatus = {
        # we're not the real gatus record-holder, so don't respond globally..
        local.denyGlobal = true;
        ssl.cert.enable = true;
      };
      prometheus = {
        # we're not the real prometheus record-holder, so don't respond globally..
        local.denyGlobal = true;
        ssl.cert.enable = true;
      };
      grafana = {
        # we're not the real mon record-holder, so don't respond globally..
        local.denyGlobal = true;
        ssl.cert.enable = true;
      };
      loki = {
        # we're not the real logs record-holder, so don't respond globally..
        local.denyGlobal = true;
        ssl.cert.enable = true;
      };
      home-assistant = {
        # not the real hass record-holder, so don't respond globally..
        local.denyGlobal = true;
        ssl.cert.enable = true;
        vouch.enable = mkIf hassVouch true;
      };
      zigbee2mqtt = {
        # not the real z2m record-holder, so don't respond globally..
        local.denyGlobal = true;
        ssl.cert.enable = true;
      };
      grocy = {
        # not the real grocy record-holder, so don't respond globally..
        local.denyGlobal = true;
        ssl.cert.enable = true;
        proxy.upstream = "tei'nginx'proxied";
      };
      barcodebuddy = {
        # not the real bbuddy record-holder, so don't respond globally..
        local.denyGlobal = true;
        ssl.cert.enable = true;
        proxy.upstream = "tei'nginx'proxied";
      };
      freepbx = {
        ssl.cert.enable = true;
      };
      prox = {
        proxied.enable = "cloudflared";
        ssl.cert.enable = true;
      };
      plex = {
        ssl.cert.enable = true;
        listen'.external = {
          enable = true;
          port = 41324;
        };
      };
      kitchencam.ssl.cert.enable = true;
      fluidd.ssl.cert.enable = true;
      openwebrx.ssl.cert.enable = true;
      deluge.ssl.cert.enable = true;
      invidious = {
        ssl.cert.enable = true;
      };
    };
    commonHttpConfig = ''
      proxy_headers_hash_max_size 1024;
      proxy_headers_hash_bucket_size 128;
    '';
  };
  services.samba.tls = {
    useACMECert = "samba";
  };
  services.syncplay = {
    openFirewall = true;
    useACMECert = "syncplay";
  };

  services.tailscale.advertiseExitNode = true;

  services.samba.openFirewall = true;

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "23.11";
}
