{
  config,
  systemConfig,
  access,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge mkOptionDefault;
  inherit (lib.strings) concatStringsSep;
  inherit (config.services) nginx;
  cfg = config.services.promtail;
in {
  config.services.promtail = {
    configuration = {
      server = {
        http_listen_port = mkOptionDefault 9094;
        grpc_listen_port = mkOptionDefault 0;
      };
      clients = let
        baseUrl = access.proxyUrlFor {serviceName = "loki";};
      in [
        {
          url = "${baseUrl}/loki/api/v1/push";
        }
      ];
      scrape_configs = let
        labels = {
          system = systemConfig.name;
          host = config.networking.fqdn;
        };
      in [
        {
          job_name = "${systemConfig.name}-journald";
          journal = {
            #json = true;
            max_age = "${toString (24 * 7)}h";
            labels = mkMerge [
              {
                job = "systemd-journald";
              }
              labels
            ];
          };
          relabel_configs = [
            {
              source_labels = ["__journal__systemd_unit"];
              target_label = "unit";
            }
            {
              source_labels = ["__journal_syslog_identifier"];
              target_label = "syslog_identifier";
            }
            {
              source_labels = ["__journal_priority_keyword"];
              target_label = "priority_keyword";
            }
            {
              source_labels = ["__journal_priority"];
              target_label = "priority";
            }
          ];
          pipeline_stages = let
            minecraftServer = [
              {
                match = {
                  selector = ''{unit="minecraft-katsink-server.service"}'';
                  pipeline_name = "minecraft-log4j";
                  stages = [
                    {
                      decolorize = {};
                    }
                    {
                      multiline = {
                        firstline = ''^(\[[^\]]+\]|[0-9A-Z]+:)'';
                        max_wait_time = "2s";
                        max_lines = 512;
                      };
                    }
                    {
                      regex.expression = concatStringsSep " " [
                        ''^\[(?P<time>[0-9:.]+)\]''
                        ''\[(?P<thread>[^\/]+)\/(?P<level>[^\]]+)\]''
                        ''\[(?P<component>[^\/]+)\/((?P<category>[^\]]+)|)\]:''
                        ''(?P<message><(?P<chat_user>[^> ]+)> (?P<chat_message>.*)|.*)$''
                      ];
                    }
                    {
                      labels = {
                        time = null;
                        thread = null;
                        level = null;
                        component = null;
                        category = null;
                        message = null;
                        chat_user = null;
                        chat_message = null;
                      };
                    }
                    {
                      timestamp = {
                        source = "time";
                        format = "15:04:05";
                      };
                    }
                  ];
                };
              }
            ];
          in
            mkMerge [
              (mkIf config.services.minecraft-katsink-server.enable minecraftServer)
            ];
        }
        (mkIf nginx.enable {
          job_name = "${systemConfig.name}-nginx-access";
          static_configs = [
            {
              labels = mkMerge [
                {
                  job = "nginx-access";
                  __path__ = "${nginx.accessLog.path}";
                }
                labels
              ];
            }
          ];
          # see https://grafana.com/docs/loki/latest/send-data/promtail/pipelines/
          # and https://grafana.com/docs/loki/latest/send-data/promtail/stages/
          pipeline_stages = [
            {
              match = {
                selector = ''{job="nginx-access"}'';
                pipeline_name = "access";
                stages = [
                  {
                    regex.expression = concatStringsSep " " [
                      ''(?P<remote_addr>.*?)(@-|@(?P<request_scheme>.*?)|)''
                      ''(-|(?P<remote_log_name>.*?))(@-|@(?P<request_id>.*?)|)''
                      ''(-|(?P<userid>.*?))(@(-|(?P<virtual_host>.*?))(@(-|(?P<server_name>.*?))(:-|:80|:443|:(?P<server_port>.*?)|)|)|)''
                      ''\[(?P<timestamp>.*?)\]''
                      ''\"(?P<request_method>.*?) (?P<path>.*?)( (?P<request_version>HTTP/.*))?\"''
                      ''(?P<status>.*?)''
                      ''(?P<length>.*?)''
                      ''\"(-|(?P<referrer>.*?))\"''
                      ''\"(-|(?P<user_agent>.*?))\"''
                    ];
                  }
                  {
                    labels = {
                      remote_addr = null;
                      remote_log_name = null;
                      request_scheme = null;
                      request_id = null;
                      userid = null;
                      virtual_host = null;
                      server_port = null;
                      server_name = null;
                      request_method = null;
                      path = null;
                      request_version = null;
                      status = null;
                      length = null;
                      referrer = null;
                      user_agent = null;
                    };
                  }
                  {
                    timestamp = {
                      source = "timestamp";
                      format = "2/Jan/2006:15:04:05 -0700";
                    };
                  }
                ];
              };
            }
          ];
        })
      ];
    };
  };
  config.systemd.services.promtail = mkIf cfg.enable {
    # TODO: there must be a better way to provide promtail access to these logs!
    serviceConfig.Group = mkIf nginx.enable (lib.mkForce nginx.group);
  };
  config.networking.firewall.interfaces.lan = let
    inherit (cfg.configuration) server;
  in
    mkIf cfg.enable {
      allowedTCPPorts = [
        server.http_listen_port
        (mkIf (server.grpc_listen_port != 0) server.grpc_listen_port)
      ];
    };
}
