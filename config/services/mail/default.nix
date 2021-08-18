{ config, lib, tf, pkgs, sources, ... }:

with lib;

{
  imports = [ sources.nixos-mailserver.outPath ];

  kw.secrets = [
    "mail-domainkey-kitty"
    "mail-kat-hash"
    "mail-gitea-hash"
  ];

  deploy.tf.dns.records.services_mail_mx = {
    tld = config.network.dns.tld;
    domain = "@";
    mx = {
      priority = 10;
      target = "${config.network.addresses.public.domain}.";
    };
  };

  deploy.tf.dns.records.services_mail_spf = {
    tld = config.network.dns.tld;
    domain = "@";
    txt.value = "v=spf1 ip4:${config.network.addresses.public.ipv4.address} ip6:${config.network.addresses.public.ipv6.address} -all";
  };

  deploy.tf.dns.records.services_mail_dmarc = {
    tld = config.network.dns.tld;
    domain = "_dmarc";
    txt.value = "v=DMARC1; p=none";
  };

  deploy.tf.dns.records.services_mail_domainkey = {
    tld = config.network.dns.tld;
    domain = "mail._domainkey";
    txt.value = tf.variables.mail-domainkey-kitty.ref;
  };

  secrets.files = {
    mail-kat-hash = {
      text = ''
        ${tf.variables.mail-kat-hash.ref}
      '';
    };
    mail-gitea-hash = {
      text = ''
        ${tf.variables.mail-gitea-hash.ref}
      '';
    };
  };

  mailserver = {
    enable = true;
    fqdn = config.network.addresses.public.domain;
    domains = [ "kittywit.ch" "dork.dev" ];
    certificateScheme = 1;
    certificateFile = "/var/lib/acme/${config.mailserver.fqdn}/cert.pem";
    keyFile = "/var/lib/acme/${config.mailserver.fqdn}/key.pem";
    enableImap = true;
    enablePop3 = true;
    enableImapSsl = true;
    enablePop3Ssl = true;
    enableSubmission = false;
    enableSubmissionSsl = true;
    enableManageSieve = true;
    virusScanning = false;

    # nix run nixpkgs.apacheHttpd -c htpasswd -nbB "" "super secret password" | cut -d: -f2
    loginAccounts = {
      "kat@kittywit.ch" = {
        hashedPasswordFile = config.secrets.files.mail-kat-hash.path;
        aliases = [ "postmaster@kittywit.ch" ];
        catchAll = [ "kittywit.ch" "dork.dev" ];
      };
      "gitea@kittywit.ch" = {
        hashedPasswordFile = config.secrets.files.mail-gitea-hash.path;
      };
    };
  };
}