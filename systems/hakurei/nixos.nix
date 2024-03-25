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
  utsuho = access.nixosFor "utsuho";
  inherit (mediabox.services) plex;
  inherit (tei.services) home-assistant zigbee2mqtt;
  inherit (utsuho.services) unifi;
  inherit (config.services) nginx;
  inherit (nginx) virtualHosts;
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
    nixos.vouch
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
    nixos.access.barcodebuddy
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
    inherit (nginx) defaultHTTPListenPort;
    tunnelId = "964121e3-b3a9-4cc1-8480-954c4728b604";
    localNginx = "http://localhost:${toString defaultHTTPListenPort}";
  in {
    tunnels.${tunnelId} = {
      default = "http_status:404";
      credentialsFile = config.sops.secrets.cloudflared-tunnel-hakurei.path;
      ingress = {
        ${virtualHosts.prox.serverName}.service = localNginx;
        ${virtualHosts.gensokyoZone.serverName}.service = localNginx;
      };
    };
  };

  # configure a secondary vouch instance for local clients, but don't use it by default
  services.vouch-proxy = {
    authUrl = "https://${virtualHosts.keycloak'local.serverName}/realms/${config.networking.domain}";
    domain = "login.local.${config.networking.domain}";
    #cookie.domain = "local.${config.networking.domain}";
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
    sso = {
      inherit (nginx) group;
      domain = virtualHosts.keycloak.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.keycloak.otherServerNames
        virtualHosts.keycloak'local.allServerNames
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
    login = {
      inherit (nginx) group;
      domain = virtualHosts.vouch.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.vouch.otherServerNames
        virtualHosts.vouch'local.allServerNames
        (mkIf virtualHosts.vouch'tail.enable virtualHosts.vouch'tail.allServerNames)
      ];
    };
    unifi = {
      inherit (nginx) group;
      domain = virtualHosts.unifi.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.unifi.otherServerNames
        virtualHosts.unifi'local.allServerNames
      ];
    };
    idp = {
      inherit (nginx) group;
      domain = virtualHosts.freeipa.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.freeipa.otherServerNames
        virtualHosts.freeipa'web.allServerNames
        virtualHosts.freeipa'web'local.allServerNames
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
    yt = {
      inherit (nginx) group;
      domain = virtualHosts.invidious.serverName;
      extraDomainNames = mkMerge [
        virtualHosts.invidious.otherServerNames
        virtualHosts.invidious'local.allServerNames
      ];
    };
  };

  services.nginx = let
    inherit (nginx) access;
    #inherit (config.lib.access) getHostnameFor;
    getHostnameFor = config.lib.access.getAddress4For;
  in {
    vouch.enableLocal = false;
    access.plex = assert plex.enable; {
      url = "http://${getHostnameFor "mediabox" "lan"}:${toString plex.port}";
      externalPort = 41324;
    };
    access.unifi = assert unifi.enable; {
      host = getHostnameFor "utsuho" "lan";
    };
    access.freeipa = {
      host = "idp.local.${config.networking.domain}";
      kerberos.ports.kpasswd = 464;
    };
    access.kitchencam = {
      streamPort = 41081;
    };
    virtualHosts = {
      fallback.ssl.cert.name = "hakurei";
      gensokyoZone.proxied.enable = "cloudflared";
      freeipa = {
        ssl.cert.enable = true;
      };
      keycloak = {
        # we're not the real sso record-holder, so don't respond globally..
        local.denyGlobal = true;
        ssl.cert.enable = true;
      };
      vouch = let
        inherit (keycloak.services) vouch-proxy;
      in assert vouch-proxy.enable; {
        ssl.cert.enable = true;
        locations."/".proxyPass = "http://${getHostnameFor "keycloak" "lan"}:${toString vouch-proxy.settings.vouch.port}";
      };
      vouch'local = let
        vouch-proxy = config.services.vouch-proxy;
      in assert vouch-proxy.enable; {
        locations."/".proxyPass = "http://localhost:${toString vouch-proxy.settings.vouch.port}";
        # we're not running another for tailscale sorry...
        name.includeTailscale = true;
      };
      unifi = {
        # we're not the real unifi record-holder, so don't respond globally..
        local.denyGlobal = true;
        ssl.cert.enable = true;
      };
      home-assistant = assert  home-assistant.enable; {
        # not the real hass record-holder, so don't respond globally..
        local.denyGlobal = true;
        ssl.cert.enable = true;
        locations."/".proxyPass = "http://${getHostnameFor "tei" "lan"}:${toString home-assistant.config.http.server_port}";
      };
      zigbee2mqtt = assert zigbee2mqtt.enable; {
        # not the real z2m record-holder, so don't respond globally..
        local.denyGlobal = true;
        ssl.cert.enable = true;
        locations."/".proxyPass = "http://${getHostnameFor "tei" "lan"}:${toString zigbee2mqtt.settings.frontend.port}";
      };
      grocy = {
        # not the real grocy record-holder, so don't respond globally..
        local.denyGlobal = true;
        ssl.cert.enable = true;
        locations."/".proxyPass = "http://${getHostnameFor "tei" "lan"}";
      };
      barcodebuddy = {
        # not the real bbuddy record-holder, so don't respond globally..
        local.denyGlobal = true;
        ssl.cert.enable = true;
        locations."/".proxyPass = "http://${getHostnameFor "tei" "lan"}";
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
        locations."/".proxyPass = "http://${getHostnameFor "mediabox" "lan"}:${toString mediabox.services.invidious.port}";
      };
    };
  };

  services.tailscale.advertiseExitNode = true;

  services.samba.openFirewall = true;

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "23.11";
}
