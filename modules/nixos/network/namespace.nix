{
  inputs,
  config,
  pkgs,
  lib,
  utils,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkBefore mkAfter mkDefault mkOptionDefault;
  inherit (lib.attrsets) mapAttrs' mapAttrsToList listToAttrs nameValuePair attrValues;
  inherit (lib.lists) singleton optional filter concatMap;
  inherit (lib.strings) concatStringsSep escapeShellArg;
  inherit (utils) escapeSystemdExecArg;
  inherit (inputs.self.lib.lib) unmerged;
  inherit (config) networking;
  inherit (networking) access;
  enabledNamespaces = filter (ns: ns.enable) (attrValues networking.namespaces);
  ip = "${pkgs.iproute2}/bin/ip";
  ip-n = namespace: "${ip} -n ${escapeShellArg namespace.name}";
  namespaceInterfaceModule = {
    config,
    namespace,
    name,
    ...
  }: {
    options = with lib.types; {
      name = mkOption {
        type = str;
        default = name;
      };
      setupScript = mkOption {
        type = lines;
      };
      stopScript = mkOption {
        type = lines;
      };
      serviceName = mkOption {
        type = str;
        default = "${namespace.unitName}-interface-${config.name}";
      };
      serviceSettings = mkOption {
        type = unmerged.type;
      };
    };
    config = {
      serviceSettings = rec {
        bindsTo = ["${namespace.unitName}.service"];
        partOf = ["${namespace.unitName}.target"];
        after = bindsTo;
        stopIfChanged = false;
        restartIfChanged = false;
        restartTriggers = [
          config.name
          namespace.name
        ];
        serviceConfig = {
          RemainAfterExit = mkDefault true;
          ExecStart = [
            ''${ip} link set dev ${escapeSystemdExecArg config.name} netns ${escapeSystemdExecArg namespace.name}''
          ];
          ExecStop = [
            ''-${ip-n namespace} link set dev ${escapeSystemdExecArg config.name} down''
            ''${ip-n namespace} link set dev ${escapeSystemdExecArg config.name} netns 1''
          ];
        };
      };
    };
  };
  groupModule = {
    config,
    namespace,
    ...
  }: {
    options = with lib.types; {
      id = mkOption {
        type = int;
      };
      serviceName = mkOption {
        type = str;
        default = "${namespace.unitName}-group-${toString config.id}";
      };
      serviceSettings = mkOption {
        type = unmerged.type;
      };
    };
    config = {
      serviceSettings = rec {
        bindsTo = ["${namespace.unitName}.service"];
        partOf = ["${namespace.unitName}.target"];
        after = bindsTo;
        stopIfChanged = false;
        restartIfChanged = false;
        restartTriggers = [
          config.id
          namespace.name
        ];
        serviceConfig = {
          RemainAfterExit = mkDefault true;
          ExecStart = [
            ''${ip} link set group ${toString config.id} netns ${escapeSystemdExecArg namespace.name}''
          ];
          ExecStop = [
            ''-${ip-n namespace} link set group ${toString config.id} down''
            ''${ip-n namespace} link set group ${toString config.id} netns 1''
          ];
        };
      };
    };
  };
  namespaceModule = {
    config,
    name,
    ...
  }: let
    linkGroupServices = optional (config.linkGroup != null) "${config.linkGroup.serviceName}.service";
    interfaceServices = mapAttrsToList (_: interface: "${interface.serviceName}.service") config.interfaces;
    submoduleArgs = {...}: {
      config._module.args.namespace = config;
    };
  in {
    options = with lib.types; {
      enable =
        mkEnableOption "network namespace"
        // {
          default = true;
        };
      resolvConf = mkOption {
        type = lines;
        default = ''
          nameserver 1.1.1.1
        '';
      };
      nftables = {
        enable = mkEnableOption "nftables";
        rejectLocaladdrs = mkEnableOption "localaddrs";
        ruleset = mkOption {
          type = lines;
        };
        serviceName = mkOption {
          type = str;
          default = "${config.unitName}-nftables";
        };
        serviceSettings = mkOption {
          type = unmerged.type;
        };
        extraInput = mkOption {
          type = lines;
          default = "";
        };
        extraOutput = mkOption {
          type = lines;
          default = "";
        };
        extraForward = mkOption {
          type = lines;
          default = "";
        };
        inputPolicy = mkOption {
          type = str;
          default = "drop";
        };
        outputPolicy = mkOption {
          type = str;
          default = "accept";
        };
        forwardPolicy = mkOption {
          type = str;
          default = "accept";
        };
      };
      dhcpcd = {
        enable = mkEnableOption "DHCP";
        package = mkOption {
          type = package;
          default = pkgs.dhcpcd;
        };
        configText = mkOption {
          type = lines;
        };
        extraConfig = mkOption {
          type = lines;
          default = "";
        };
        serviceName = mkOption {
          type = str;
          default = "${config.unitName}-dhcpcd";
        };
        serviceSettings = mkOption {
          type = unmerged.type;
        };
      };
      name = mkOption {
        type = str;
        default = name;
      };
      linkGroup = mkOption {
        type = let
          module = submodule [
            groupModule
            submoduleArgs
          ];
          idOrModule = coercedTo int (id: {inherit id;}) module;
        in
          nullOr idOrModule;
        default = null;
      };
      interfaces = mkOption {
        type = attrsOf (submodule [
          namespaceInterfaceModule
          submoduleArgs
        ]);
        default = {};
      };
      path = mkOption {
        type = path;
        default = "/run/netns/${config.name}";
      };
      configDir = mkOption {
        type = str;
        default = "netns/${config.name}";
      };
      configPath = mkOption {
        type = path;
        readOnly = true;
        default = "/etc/${config.configDir}";
      };
      unitName = mkOption {
        type = str;
        default = "netns-${config.name}";
      };
      serviceSettings = mkOption {
        type = unmerged.type;
      };
      targetSettings = mkOption {
        type = unmerged.type;
      };
      configFiles = mkOption {
        type = attrsOf unmerged.type;
      };
    };
    config = {
      serviceSettings = {
        wants = ["network.target"];
        after = ["network.target"];
        stopIfChanged = false;
        restartIfChanged = false;
        serviceConfig = {
          RemainAfterExit = mkDefault true;
          ConfigurationDirectory = mkDefault config.configDir;
          ExecStart = [
            ''${ip} netns add ${escapeSystemdExecArg config.name}''
          ];
          ExecStartPost = [
            ''-${ip-n config} link set dev lo up''
          ];
          ExecStop = [
            ''${ip} netns delete ${escapeSystemdExecArg config.name}''
          ];
        };
      };
      targetSettings = {
        wantedBy = ["multi-user.target"];
        bindsTo = ["${config.unitName}.service"];
        requires = linkGroupServices ++ interfaceServices;
        wants = mkMerge [
          (mkIf config.dhcpcd.enable ["${config.dhcpcd.serviceName}.service"])
          (mkIf config.nftables.enable ["${config.nftables.serviceName}.service"])
        ];
      };
      configFiles = {
        "resolv.conf".text = mkDefault config.resolvConf;
        "dhcpcd.conf" = mkIf config.dhcpcd.enable {
          text = mkDefault config.dhcpcd.configText;
        };
        "rules.nft" = mkIf config.nftables.enable {
          text = mkDefault config.nftables.ruleset;
        };
      };
      nftables = {
        ruleset = mkMerge [
          (mkIf config.nftables.rejectLocaladdrs (
            assert access.localaddrs.enable; mkBefore access.localaddrs.nftablesInclude
          ))
          ''
            table inet filter {
              chain input {
                type filter hook input priority filter
                policy ${config.nftables.inputPolicy}

                icmpv6 type { echo-request, echo-reply, mld-listener-query, mld-listener-report, mld-listener-done, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert, packet-too-big } accept
                icmp type echo-request accept

                ct state invalid drop
                ct state established,related accept

                iifname lo accept

                # DHCPv6
                ip6 daddr fe80::/64 udp dport 546 accept

                ${config.nftables.extraInput}

                counter
              }
              chain output {
                type filter hook output priority filter
                policy ${config.nftables.outputPolicy}

                ${config.nftables.extraOutput}

                counter
              }
              chain forward {
                type filter hook forward priority filter
                policy ${config.nftables.forwardPolicy}

                ${config.nftables.extraForward}

                counter
              }
            }
          ''
        ];
        extraOutput = let
          addrs4 = access.cidrForNetwork.allLocal.v4;
          addrs6 = access.cidrForNetwork.allLocal.v6;
          daddr4 = ''{ ${concatStringsSep ", " addrs4} }'';
          daddr6 = ''{ ${concatStringsSep ", " addrs6} }'';
        in
          mkIf config.nftables.rejectLocaladdrs (mkMerge [
            ''ct state { established, related } accept''
            ''
              ip daddr ${daddr4} ip protocol tcp reject with tcp reset
              ip daddr ${daddr4} drop
            ''
            (mkIf networking.enableIPv6 ''
              ip6 daddr ${daddr6} ip6 nexthdr tcp reject with tcp reset
              ip6 daddr ${daddr6} drop
            '')
          ]);
        serviceSettings = rec {
          bindsTo = ["${config.unitName}.service"];
          partOf = ["${config.unitName}.target"];
          wants = mkIf config.nftables.rejectLocaladdrs ["localaddrs.service"];
          after = mkMerge [
            bindsTo
            wants
          ];
          restartIfChanged = false;
          reloadTriggers = [
            config.nftables.ruleset
          ];
          serviceConfig = {
            NetworkNamespacePath = mkOptionDefault config.path;

            Type = mkOptionDefault "oneshot";
            RemainAfterExit = mkOptionDefault true;
            StateDirectory = mkOptionDefault config.nftables.serviceName;

            ExecStart = [
              "${pkgs.nftables}/bin/nft -f ${config.configPath}/rules.nft"
            ];
            ExecReload = mkMerge [
              (mkIf config.nftables.rejectLocaladdrs ["+${access.localaddrs.reloadScript}"])
              [
                "${pkgs.nftables}/bin/nft flush ruleset"
                "${pkgs.nftables}/bin/nft -f ${config.configPath}/rules.nft"
              ]
            ];
            ExecStop = [
              "${pkgs.nftables}/bin/nft flush ruleset"
            ];
          };
        };
      };
      dhcpcd = {
        serviceSettings = rec {
          bindsTo = ["${config.unitName}.service"];
          partOf = ["${config.unitName}.target"];
          wants = linkGroupServices ++ interfaceServices;
          after =
            bindsTo
            ++ wants
            ++ [
              (mkIf config.nftables.enable "${config.nftables.serviceName}.service")
            ];
          stopIfChanged = false;
          unitConfig.ConditionCapability = "CAP_NET_ADMIN";
          serviceConfig = {
            NetworkNamespacePath = mkOptionDefault config.path;
            BindReadOnlyPaths = [
              "${config.configPath}/resolv.conf:/etc/resolv.conf"
            ];
            BindPaths = [
              "/run/${config.dhcpcd.serviceName}/:/run/dhcpcd"
              "/var/lib/${config.dhcpcd.serviceName}/:/var/lib/dhcpcd"
              "${config.configPath}/dhcpcd.conf:/etc/dhcpcd.conf"
            ];

            Type = mkOptionDefault "forking";
            Restart = mkOptionDefault "always";
            PIDFile = mkOptionDefault "/run/${config.dhcpcd.serviceName}/pid";
            RuntimeDirectory = mkOptionDefault config.dhcpcd.serviceName;
            StateDirectory = mkOptionDefault config.dhcpcd.serviceName;

            ExecStart = [
              "@${config.dhcpcd.package}/sbin/dhcpcd dhcpcd --quiet --config ${config.configPath}/dhcpcd.conf"
            ];
            ExecReload = [
              "${config.dhcpcd.package}/sbin/dhcpcd --rebind"
            ];
          };
        };
        configText = mkMerge [
          ''
            hostname
            option domain_name_servers, domain_name, domain_search, host_name
            option classless_static_routes, ntp_servers, interface_mtu
            nohook lookup-hostname
            slaac hwaddr
            waitip
          ''
          (mkAfter config.dhcpcd.extraConfig)
        ];
      };
    };
  };
  serviceModule = {
    config,
    name,
    ...
  }: let
    cfg = config.networkNamespace;
    hasNs = cfg.name != null;
    ns = networking.namespaces.${cfg.name};
  in {
    options.networkNamespace = with lib.types; {
      enable =
        mkEnableOption "netns"
        // {
          default = cfg.name != null;
        };
      bindResolvConf = mkOption {
        type = nullOr path;
      };
      afterOnline = mkOption {
        type = bool;
        default = false;
      };
      privateMounts = mkOption {
        type = bool;
        default = true;
      };
      name = mkOption {
        type = nullOr str;
        default = null;
      };
      path = mkOption {
        type = nullOr path;
      };
    };
    config = mkMerge [
      {
        networkNamespace = mkMerge [
          {
            path = mkOptionDefault null;
            bindResolvConf = mkOptionDefault null;
          }
          (mkIf hasNs {
            path = mkDefault (
              ns.path
            );
            bindResolvConf = mkDefault "${ns.configPath}/resolv.conf";
          })
        ];
      }
      (mkIf cfg.enable rec {
        wants = mkIf hasNs ["${ns.unitName}.target"];
        bindsTo = mkIf hasNs ["${ns.unitName}.service"];
        after = mkMerge [
          bindsTo
          (mkIf (hasNs && cfg.afterOnline) [
            "${ns.unitName}.target"
          ])
        ];
        serviceConfig = {
          NetworkNamespacePath = mkOptionDefault cfg.path;
          PrivateMounts = mkIf (!cfg.privateMounts) (mkDefault false);
          BindReadOnlyPaths = mkIf (cfg.bindResolvConf != null) [
            "${cfg.bindResolvConf}:/etc/resolv.conf"
          ];
        };
      })
    ];
  };
in {
  options = with lib.types; {
    networking.namespaces = mkOption {
      type = attrsOf (submodule namespaceModule);
      default = {};
    };
    systemd.services = mkOption {
      type = attrsOf (submodule serviceModule);
    };
  };
  config = {
    systemd = {
      services = listToAttrs (concatMap (
          ns:
            singleton (nameValuePair ns.unitName (unmerged.merge ns.serviceSettings))
            ++ optional (ns.linkGroup != null) (nameValuePair ns.linkGroup.serviceName (unmerged.merge ns.linkGroup.serviceSettings))
            ++ mapAttrsToList (_: interface: nameValuePair interface.serviceName (unmerged.merge interface.serviceSettings)) ns.interfaces
            ++ optional ns.dhcpcd.enable (nameValuePair ns.dhcpcd.serviceName (unmerged.merge ns.dhcpcd.serviceSettings))
            ++ optional ns.nftables.enable (nameValuePair ns.nftables.serviceName (unmerged.merge ns.nftables.serviceSettings))
        )
        enabledNamespaces);
      targets = listToAttrs (map (ns:
        nameValuePair ns.unitName (
          unmerged.merge ns.targetSettings
        ))
      enabledNamespaces);
    };
    environment.etc = mkMerge (map (
        ns:
          mapAttrs' (name: file: nameValuePair "${ns.configDir}/${name}" (unmerged.merge file)) ns.configFiles
      )
      enabledNamespaces);
  };
}
