{
  config,
  meta,
  lib,
  access,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
  keycloak = access.nixosFor "keycloak";
  mediabox = access.nixosFor "mediabox";
  tei = access.nixosFor "tei";
  inherit (mediabox.services) plex;
  inherit (keycloak.services) vouch-proxy;
  inherit (tei.services) home-assistant zigbee2mqtt;
  inherit (config.services) nginx tailscale;
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
    nixos.ddclient
    nixos.acme
    nixos.nginx
    nixos.access.nginx
    nixos.access.global
    nixos.access.gensokyo
    nixos.access.keycloak
    nixos.access.vouch
    nixos.access.freeipa
    nixos.access.freepbx
    nixos.access.unifi
    nixos.access.kitchencam
    nixos.access.home-assistant
    nixos.access.zigbee2mqtt
    nixos.access.grocy
    nixos.access.proxmox
    nixos.access.plex
    nixos.access.invidious
    nixos.samba
    ./reisen-ssh.nix
  ];

  sops.secrets.cloudflared-tunnel-hakurei = {
    owner = config.services.cloudflared.user;
  };

  services.cloudflared = let
    inherit (nginx) virtualHosts;
    tunnelId = "964121e3-b3a9-4cc1-8480-954c4728b604";
  in {
    tunnels.${tunnelId} = {
      default = "http_status:404";
      credentialsFile = config.sops.secrets.cloudflared-tunnel-hakurei.path;
      ingress = {
        ${virtualHosts.prox.serverName}.service = "http://localhost";
        ${virtualHosts.gensokyoZone.serverName}.service = "http://localhost";
      };
    };
  };

  security.acme.certs = let
    inherit (nginx) access virtualHosts;
  in {
    hakurei = {
      inherit (nginx) group;
      domain = config.networking.fqdn;
      extraDomainNames = [
        config.lib.access.hostnameForNetwork.local
        (mkIf config.services.tailscale.enable config.lib.access.hostnameForNetwork.tail)
      ];
    };
    sso = {
      inherit (nginx) group;
      domain = virtualHosts.keycloak.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.keycloak.serverAliases
        virtualHosts.keycloak'local.allServerNames
      ];
    };
    home = {
      inherit (nginx) group;
      domain = virtualHosts.home-assistant.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.home-assistant.serverAliases
        virtualHosts.home-assistant'local.allServerNames
      ];
    };
    z2m = {
      inherit (nginx) group;
      domain = virtualHosts.zigbee2mqtt.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.zigbee2mqtt.serverAliases
        virtualHosts.zigbee2mqtt'local.allServerNames
      ];
    };
    grocy = {
      inherit (nginx) group;
      domain = virtualHosts.grocy.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.grocy.serverAliases
        virtualHosts.grocy'local.allServerNames
      ];
    };
    login = {
      inherit (nginx) group;
      domain = virtualHosts.vouch.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.vouch.serverAliases
        virtualHosts.vouch'local.allServerNames
        (mkIf virtualHosts.vouch'tail.enable virtualHosts.vouch'tail.allServerNames)
      ];
    };
    unifi = {
      inherit (nginx) group;
      domain = virtualHosts.unifi.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.unifi.serverAliases
        virtualHosts.unifi'local.allServerNames
      ];
    };
    ${access.freeipa.domain} = {
      inherit (nginx) group;
      extraDomainNames = mkMerge [
        [
          access.freeipa.localDomain
          access.freeipa.caDomain
          access.freeipa.globalDomain
          access.ldap.domain
          access.ldap.localDomain
        ]
        (mkIf tailscale.enable [
          access.freeipa.tailDomain
          access.ldap.tailDomain
        ])
      ];
    };
    pbx = {
      inherit (nginx) group;
      domain = virtualHosts.freepbx.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.freepbx.serverAliases
        virtualHosts.freepbx'local.allServerNames
      ];
    };
    prox = {
      inherit (nginx) group;
      domain = virtualHosts.prox.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.prox.serverAliases
        virtualHosts.prox'local.allServerNames
        (mkIf virtualHosts.prox'tail.enable virtualHosts.prox'tail.allServerNames)
      ];
    };
    plex = {
      inherit (nginx) group;
      domain = virtualHosts.plex.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.plex.serverAliases
        virtualHosts.plex'local.allServerNames
      ];
    };
    kitchen = {
      inherit (nginx) group;
      domain = virtualHosts.kitchencam.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.kitchencam.serverAliases
        virtualHosts.kitchencam'local.allServerNames
      ];
    };
    yt = {
      inherit (nginx) group;
      domain = virtualHosts.invidious.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.invidious.serverAliases
        virtualHosts.invidious'local.allServerNames
      ];
    };
  };

  services.nginx = let
    inherit (nginx) access;
  in {
    access.plex = assert plex.enable; {
      url = "http://${mediabox.lib.access.hostnameForNetwork.local}:${toString plex.port}";
      externalPort = 41324;
    };
    access.vouch = assert vouch-proxy.enable; {
      url = "http://${keycloak.lib.access.hostnameForNetwork.local}:${toString vouch-proxy.settings.vouch.port}";
    };
    access.unifi = {
      host = tei.lib.access.hostnameForNetwork.local;
    };
    access.freeipa = {
      useACMEHost = access.freeipa.domain;
      host = "idp.local.${config.networking.domain}";
      kerberos.ports.kpasswd = 464;
    };
    access.kitchencam = {
      streamPort = 41081;
    };
    virtualHosts = {
      fallback.ssl.cert.name = "hakurei";
      gensokyoZone.proxied.enable = "cloudflared";
      keycloak = {
        # we're not the real sso record-holder, so don't respond globally..
        local.denyGlobal = true;
        ssl.cert.enable = true;
      };
      vouch.ssl.cert.enable = true;
      unifi = {
        # we're not the real unifi record-holder, so don't respond globally..
        local.denyGlobal = true;
        ssl.cert.enable = true;
      };
      home-assistant = assert  home-assistant.enable; {
        # not the real hass record-holder, so don't respond globally..
        local.denyGlobal = true;
        ssl.cert.enable = true;
        locations."/".proxyPass = "http://${tei.lib.access.hostnameForNetwork.tail}:${toString home-assistant.config.http.server_port}";
      };
      zigbee2mqtt = assert zigbee2mqtt.enable; {
        # not the real z2m record-holder, so don't respond globally..
        local.denyGlobal = true;
        ssl.cert.enable = true;
        locations."/".proxyPass = "http://${tei.lib.access.hostnameForNetwork.tail}:${toString zigbee2mqtt.settings.frontend.port}";
      };
      grocy = {
        # not the real grocy record-holder, so don't respond globally..
        local.denyGlobal = true;
        ssl.cert.enable = true;
        locations."/".proxyPass = "http://${tei.lib.access.hostnameForNetwork.tail}";
      };
      freepbx = {
        ssl.cert.enable = true;
      };
      prox = {
        proxied.enable = "cloudflared";
        ssl.cert.enable = true;
      };
      plex.ssl.cert.enable = true;
      kitchencam.ssl.cert.enable = true;
      invidious = {
        ssl.cert.enable = true;
      };
      invidious'int = {
        locations."/".proxyPass = "http://${mediabox.lib.access.hostnameForNetwork.local}:${toString mediabox.services.invidious.port}";
      };
    };
  };

  services.tailscale.advertiseExitNode = true;

  services.samba.openFirewall = true;

  systemd.network.networks.eth0 = {
    name = "eth0";
    matchConfig = {
      MACAddress = "BC:24:11:C4:66:A7";
      Type = "ether";
    };
    address = ["10.1.1.41/24"];
    gateway = ["10.1.1.1"];
    DHCP = "no";
  };

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "23.11";
}
