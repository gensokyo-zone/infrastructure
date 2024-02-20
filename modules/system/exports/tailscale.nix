{...}: {
  config.exports.services.tailscale = {
    id = "tail";
    nixos.serviceAttr = "tailscale";
    ports = {};
  };
}
