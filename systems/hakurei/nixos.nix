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
  inherit (tei.services) kanidm;
in {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.sops
    nixos.base
    nixos.reisen-ct
    nixos.tailscale
    nixos.cloudflared
    nixos.ddclient
    nixos.acme
    nixos.nginx
    nixos.access.nginx
    nixos.access.global
    nixos.access.gensokyo
    nixos.access.kanidm
    nixos.access.proxmox
    nixos.access.plex
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
        [ access.kanidm.localDomain ]
        (mkIf kanidm.server.ldap.enable [
          access.kanidm.ldapDomain
          access.kanidm.ldapLocalDomain
        ])
        (mkIf tailscale.enable [
          access.kanidm.tailDomain
        ])
        (mkIf (kanidm.server.ldap.enable && tailscale.enable) [
          access.kanidm.ldapTailDomain
        ])
      ];
    };
    ${access.proxmox.domain} = {
      inherit (nginx) group;
      extraDomainNames = mkMerge [
        [ access.proxmox.localDomain ]
        (mkIf config.services.tailscale.enable [
          access.proxmox.tailDomain
        ])
      ];
    };
    ${access.plex.domain} = {
      inherit (nginx) group;
      extraDomainNames = [ access.plex.localDomain ];
    };
  };

  services.nginx = let
    inherit (config.services.nginx) access;
  in {
    access.plex = assert plex.enable; {
      url = "http://${mediabox.networking.access.hostnameForNetwork.local}:32400";
    };
    access.kanidm = assert kanidm.enableServer; {
      domain = kanidm.server.frontend.domain;
      host = tei.networking.access.hostnameForNetwork.local;
      port = kanidm.server.frontend.port;
      ldapPort = kanidm.server.ldap.port;
      ldapEnable = kanidm.server.ldap.enable;
    };
    virtualHosts = {
      ${access.kanidm.domain} = {
        useACMEHost = access.kanidm.domain;
      };
      ${access.proxmox.domain} = {
        useACMEHost = access.proxmox.domain;
      };
      ${access.plex.domain} = {
        addSSL = true;
        useACMEHost = access.plex.domain;
      };
    };
  };

  systemd.network.networks.eth0 = {
    name = "eth0";
    matchConfig = {
      MACAddress = "BC:24:11:C4:66:A7";
      Type = "ether";
    };
    address = [ "10.1.1.41/24" ];
    gateway = [ "10.1.1.1" ];
    DHCP = "no";
  };

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "23.11";
}
