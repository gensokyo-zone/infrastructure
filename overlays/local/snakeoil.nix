{
  runCommand,
  buildPackages,
  lib,
}: let
  inherit (lib.strings) concatStringsSep;
  inherit (lib.lists) toList head;
in { domain, name }: runCommand name {
  domains = concatStringsSep "," (toList domain);
  domain = head (toList domain);
  nativeBuildInputs = [ buildPackages.minica ];
  outputs = [ "out" "key" "cakey" "ca" "cert" "fullchain" ];
} ''
  install -d $out
  minica \
    --ca-key ca.key.pem \
    --ca-cert ca.pem \
    --domains "$domains"
  mv ca.pem $ca
  mv ca.key.pem $cakey
  mv $domain/cert.pem $cert
  mv $domain/key.pem $key
  cat $cert $ca > $fullchain

  ln -s $fullchain $out/fullchain.pem
  ln -s $key $out/key.pem
  ln -s $cakey $out/ca.key.pem
  ln -s $cert $out/cert.pem
  ln -s $ca $out/ca.pem
''
