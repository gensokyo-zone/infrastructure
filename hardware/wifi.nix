{ config, tf, lib, ... }:

let
  inherit (lib.attrsets) mapListToAttrs nameValuePair;
  inherit (lib.modules) mkIf;
in {
  kw.secrets.variables = mapListToAttrs
    (field:
      nameValuePair "wireless-${field}" {
        path = "secrets/wifi";
        inherit field;
      }) [ "ssid" "psk" ];

  deploy.tf.resources = {
    wireless-credentials = {
      provider = "null";
      type = "data_source";
      dataSource = true;
      inputs.inputs = {
        ssid = tf.variables.wireless-ssid.ref;
        psk = tf.variables.wireless-psk.ref;
      };
    };
  };

  networking.wireless = {
    enable = true;
    networks = mkIf (builtins.getEnv "TF_IN_AUTOMATION" != "" || tf.state.enable) {
      ${builtins.unsafeDiscardStringContext (tf.resources.wireless-credentials.getAttr "outputs.ssid")} = {
        pskRaw = tf.resources.wireless-credentials.getAttr "outputs.psk";
      };
    };
  };
}
