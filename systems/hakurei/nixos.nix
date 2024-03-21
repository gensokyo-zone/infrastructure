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
    tunnelId = "964121e3-b3a9-4cc1-8480-954c4728b604";
  in {
    tunnels.${tunnelId} = {
      default = "http_status:404";
      credentialsFile = config.sops.secrets.cloudflared-tunnel-hakurei.path;
      ingress = {
        "prox.${config.networking.domain}".service = "http://localhost";
        ${config.networking.domain}.service = "http://localhost";
      };
    };
  };

  security.acme.certs = let
    inherit (nginx) access virtualHosts;
  in {
    keycloak = {
      inherit (nginx) group;
      domain = virtualHosts.keycloak.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.keycloak.serverAliases
        virtualHosts.keycloak'local.allServerNames
      ];
    };
    home-assistant = {
      inherit (nginx) group;
      domain = virtualHosts.home-assistant.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.home-assistant.serverAliases
        virtualHosts.home-assistant'local.allServerNames
      ];
    };
    zigbee2mqtt = {
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
    vouch = {
      inherit (nginx) group;
      domain = virtualHosts.vouch.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.vouch.serverAliases
        virtualHosts.vouch'local.allServerNames
        (mkIf tailscale.enable virtualHosts.vouch'tail.allServerNames)
      ];
    };
    ${access.unifi.domain} = {
      inherit (nginx) group;
      extraDomainNames = mkMerge [
        [access.unifi.localDomain]
        (mkIf tailscale.enable [
          access.unifi.tailDomain
        ])
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
    ${access.freepbx.domain} = {
      inherit (nginx) group;
      extraDomainNames = mkMerge [
        [
          access.freepbx.localDomain
        ]
        (mkIf tailscale.enable [
          access.freepbx.tailDomain
        ])
      ];
    };
    ${access.proxmox.domain} = {
      inherit (nginx) group;
      extraDomainNames = mkMerge [
        [access.proxmox.localDomain]
        (mkIf config.services.tailscale.enable [
          access.proxmox.tailDomain
        ])
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
    kitchencam = {
      inherit (nginx) group;
      domain = virtualHosts.kitchencam.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.kitchencam.serverAliases
        virtualHosts.kitchencam'local.allServerNames
      ];
    };
    ${access.invidious.domain} = {
      inherit (nginx) group;
      extraDomainNames = mkMerge [
        [
          access.invidious.localDomain
        ]
        (mkIf tailscale.enable [
          access.invidious.tailDomain
        ])
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
      useACMEHost = access.unifi.domain;
    };
    access.freeipa = {
      useACMEHost = access.freeipa.domain;
      host = "idp.local.${config.networking.domain}";
      kerberos.ports.kpasswd = 464;
    };
    access.freepbx = {
      useACMEHost = access.freepbx.domain;
    };
    access.kitchencam = {
      streamPort = 41081;
    };
    access.invidious = {
      url = "http://${mediabox.lib.access.hostnameForNetwork.local}:${toString mediabox.services.invidious.port}";
    };
    virtualHosts = {
      gensokyoZone.proxied.enable = "cloudflared";
      keycloak = {
        # we're not the real sso record-holder, so don't respond globally..
        local.denyGlobal = true;
        ssl.cert.name = "keycloak";
      };
      keycloak'local.ssl.cert.name = "keycloak";
      vouch.ssl.cert.name = "vouch";
      vouch'local.ssl.cert.name = "vouch";
      vouch'tail = mkIf tailscale.enable {
        ssl.cert.name = "vouch";
      };
      home-assistant = assert  home-assistant.enable; {
        # not the real hass record-holder, so don't respond globally..
        local.denyGlobal = true;
        ssl.cert.name = "home-assistant";
        locations."/".proxyPass = "http://${tei.lib.access.hostnameForNetwork.tail}:${toString home-assistant.config.http.server_port}";
      };
      home-assistant'local.ssl.cert.name = "home-assistant";
      zigbee2mqtt = assert zigbee2mqtt.enable; {
        # not the real z2m record-holder, so don't respond globally..
        local.denyGlobal = true;
        ssl.cert.name = "zigbee2mqtt";
        locations."/".proxyPass = "http://${tei.lib.access.hostnameForNetwork.tail}:${toString zigbee2mqtt.settings.frontend.port}";
      };
      zigbee2mqtt'local.ssl.cert.name = "zigbee2mqtt";
      grocy = {
        # not the real grocy record-holder, so don't respond globally..
        local.denyGlobal = true;
        ssl.cert.name = "grocy";
        locations."/".proxyPass = "http://${tei.lib.access.hostnameForNetwork.tail}";
      };
      grocy'local = {
        ssl.cert.name = "grocy";
      };
      ${access.freepbx.domain} = {
        local.enable = true;
      };
      ${access.proxmox.domain} = {
        useACMEHost = access.proxmox.domain;
      };
      plex.ssl.cert.name = "plex";
      plex'local.ssl.cert.name = "plex";
      kitchencam.ssl.cert.name = "kitchencam";
      kitchencam'local.ssl.cert.name = "kitchencam";
      ${access.invidious.domain} = {
        useACMEHost = access.invidious.domain;
        forceSSL = true;
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
