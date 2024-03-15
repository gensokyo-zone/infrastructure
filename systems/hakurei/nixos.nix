{
  config,
  meta,
  lib,
  access,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
  mediabox = access.nixosFor "mediabox";
  tei = access.nixosFor "tei";
  inherit (mediabox.services) plex;
  inherit (tei.services) kanidm vouch-proxy;
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
    nixos.access.vouch
    nixos.access.kanidm
    nixos.access.freeipa
    nixos.access.freepbx
    nixos.access.unifi
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
    inherit (nginx) access;
  in {
    ${access.vouch.localDomain} = {
      inherit (nginx) group;
      extraDomainNames = mkMerge [
        (mkIf tailscale.enable [
          access.vouch.tailDomain
        ])
      ];
    };
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
      url = "http://${tei.lib.access.hostnameForNetwork.tail}:${toString vouch-proxy.settings.vouch.port}";
      useACMEHost = access.vouch.localDomain;
    };
    access.kanidm = assert kanidm.enableServer; {
      inherit (kanidm.server.frontend) domain port;
      host = tei.lib.access.hostnameForNetwork.local;
      ldapEnable = false;
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
      useACMEHost = access.kitchencam.domain;
    };
    access.invidious = {
      url = "http://${mediabox.lib.access.hostnameForNetwork.local}:${toString mediabox.services.invidious.port}";
    };
    virtualHosts = {
      ${access.kanidm.domain} = {
        useACMEHost = access.kanidm.domain;
      };
      ${access.freepbx.domain} = {
        local.enable = true;
      };
      ${access.proxmox.domain} = {
        useACMEHost = access.proxmox.domain;
      };
      ${access.plex.domain} = {
        addSSL = true;
        useACMEHost = access.plex.domain;
      };
      ${access.kitchencam.domain} = {
      };
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
