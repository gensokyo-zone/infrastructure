{
  config,
  meta,
  lib,
  access,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
  mediabox = access.systemFor "mediabox";
  tei = access.systemFor "tei";
  inherit (mediabox.services) plex;
  inherit (tei.services) kanidm vouch-proxy;
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
    nixos.cloudflared
    nixos.ddclient
    nixos.acme
    nixos.nginx
    nixos.access.nginx
    nixos.access.global
    nixos.access.gensokyo
    nixos.access.kanidm
    nixos.access.freeipa
    nixos.access.kitchencam
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
    inherit (config.services) nginx tailscale;
    inherit (nginx) access;
  in {
    ${access.kanidm.domain} = {
      inherit (nginx) group;
      extraDomainNames = mkMerge [
        [access.kanidm.localDomain]
        (mkIf access.kanidm.ldapEnable [
          access.kanidm.ldapDomain
          access.kanidm.ldapLocalDomain
        ])
        (mkIf tailscale.enable [
          access.kanidm.tailDomain
        ])
        (mkIf (access.kanidm.ldapEnable && tailscale.enable) [
          access.kanidm.ldapTailDomain
        ])
      ];
    };
    ${access.freeipa.domain} = {
      inherit (nginx) group;
      extraDomainNames = mkMerge [
        [
          access.freeipa.localDomain
          access.ldap.domain
          access.ldap.localDomain
        ]
        (mkIf tailscale.enable [
          access.freeipa.tailDomain
          access.ldap.tailDomain
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
    ${access.plex.domain} = {
      inherit (nginx) group;
      extraDomainNames = [access.plex.localDomain];
    };
    ${access.kitchencam.domain} = {
      inherit (nginx) group;
      extraDomainNames = mkMerge [
        [
          access.kitchencam.localDomain
        ]
        (mkIf tailscale.enable [
          access.kitchencam.tailDomain
        ])
      ];
    };
    ${access.invidious.domain} = {
      inherit (nginx) group;
      extraDomainNames = mkMerge [
        access.invidious.localDomain
      ];
    };
  };

  services.nginx = let
    inherit (config.services.nginx) access;
  in {
    access.plex = assert plex.enable; {
      url = "http://${mediabox.networking.access.hostnameForNetwork.local}:32400";
    };
    access.kanidm = assert kanidm.enableServer; {
      inherit (kanidm.server.frontend) domain port;
      host = tei.networking.access.hostnameForNetwork.local;
      ldapEnable = false;
    };
    access.freeipa = {
      host = "idp.local.${config.networking.domain}";
    };
    access.kitchencam = {
      streamPort = 41081;
      useACMEHost = access.kitchencam.domain;
    };
    access.invidious = {
      url = "http://${mediabox.networking.access.hostnameForNetwork.local}:${mediabox.services.invidious.port}";
    };
    virtualHosts = {
      ${access.kanidm.domain} = {
        useACMEHost = access.kanidm.domain;
      };
      ${access.freeipa.domain} = {
        forceSSL = true;
        useACMEHost = access.freeipa.domain;
      };
      ${access.proxmox.domain} = {
        useACMEHost = access.proxmox.domain;
      };
      ${access.plex.domain} = {
        addSSL = true;
        useACMEHost = access.plex.domain;
      };
      ${access.kitchencam.domain} = {
        vouch = {
          authUrl = vouch-proxy.authUrl;
          url = vouch-proxy.url;
          proxyOrigin = "http://${tei.networking.access.hostnameForNetwork.tail}:${toString vouch-proxy.settings.vouch.port}";
        };
      };
      ${access.invidious.domain} = {
        vouch = {
          authUrl = vouch-proxy.authUrl;
          url = vouch-proxy.url;
          proxyOrigin = "http://${tei.networking.access.hostnameForNetwork.tail}:${toString vouch-proxy.settings.vouch.port}";
        };
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
