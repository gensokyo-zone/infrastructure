{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (lib.strings) optionalString makeBinPath;
  inherit (lib.meta) getExe;
  cfg = config.services.barcodebuddy-scanner;
  user = "barcodebuddy-scanner";
  notifyEnv = ''
    export PATH="$PATH:${makeBinPath [pkgs.libnotify pkgs.dbus pkgs.jq]}"
    export DISPLAY=''${DISPLAY-:0}
    export XDG_RUNTIME_DIR=/run/user/${toString config.users.users.${cfg.user}.uid}
    export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus
  '';
  notify-send = ''
    timeout 1 notify-send "$@" 2>/dev/null || true
  '';
  scanCommand = pkgs.writeShellScriptBin "barcodebuddy-scanner-cmd" ''
    set -eu
    BARCODE=$1
    SUBMIT_URL="''${SERVER_ADDRESS}action/scan?apikey=''${API_KEY}&add=$BARCODE"
    ${optionalString config.services.xserver.enable notifyEnv}

    notify-send() {
      ${optionalString config.services.xserver.enable notify-send}
      :
    }

    echo "Scanned barcode: $BARCODE" >&2
    NOTIF_ID=$(notify-send \
      -p \
      --expire-time $((10*1000)) \
      "Scanning barcode..." \
      "$BARCODE"
    )

    CURL_DATA=$(${getExe pkgs.curl} -fSsL "$SUBMIT_URL") && CURL_RESULT=0 || CURL_RESULT=$?
    printf '%s\n' "$CURL_DATA" >&2

    if [[ $CURL_RESULT -ne 0 ]]; then
      notify-send \
        -r "$NOTIF_ID" \
        --expire-time $((60*1000)) \
        "Barcode submission failed" \
        "$(${config.systemd.package}/bin/journalctl -e -o cat -n 8 -u barcodebuddy-scanner.service)"
    elif [[ -n $CURL_DATA ]]; then
      if RESPONSE_RESULT=$(jq -er .data.result 2>/dev/null <<<"$CURL_DATA"); then
        notify-send \
          -r "$NOTIF_ID" \
          --expire-time $((30*1000)) \
          "Scanned Barcode: $BARCODE" \
          "$RESPONSE_RESULT"
      fi
    else
      notify-send \
        -r "$NOTIF_ID" \
        --expire-time $((30*1000)) \
        "Scanned Barcode" \
        "$BARCODE"
    fi

    exit $CURL_RESULT
  '';
in {
  config.services.barcodebuddy-scanner = {
    enable = mkDefault true;
    # TODO: use access and possibly int for the URL?
    serverAddress = mkDefault "https://bbuddy.local.${config.networking.domain}/api/";
    apiKeyPath = mkDefault config.sops.secrets.barcodebuddy-scanner-apikey.path;
    user = mkDefault user;
    udevMatchRules = [
      ''ATTRS{idVendor}=="1a86"''
      ''ATTRS{idProduct}=="5456"''
    ];
    scanCommand = mkDefault "${getExe scanCommand}";
  };
  config.users = mkIf cfg.enable {
    users.${user} = {
      isSystemUser = true;
      group = user;
      uid = 914;
    };
    groups.${user} = {
      gid = config.users.users.${user}.uid;
    };
  };
  config.sops.secrets.barcodebuddy-scanner-apikey = mkIf cfg.enable {
    sopsFile = mkDefault ./secrets/barcodebuddy.yaml;
    owner = mkDefault cfg.user;
  };
}
