locals {
  idp_fqdn    = "idp.${cloudflare_zone.gensokyo-zone_zone.zone}"
  idp_uri_udp = "krb5srv:m:udp:${local.idp_fqdn}."
  idp_uri_tcp = "krb5srv:m:tcp:${local.idp_fqdn}."
}

resource "cloudflare_record" "kerberos_master_tcp" {
  zone_id = cloudflare_zone.gensokyo-zone_zone.id
  name    = "_kerberos-master._tcp"
  type    = "SRV"
  ttl     = 3600
  data {
    priority = 0
    weight   = 100
    port     = 88
    target   = local.idp_fqdn
  }
}

resource "cloudflare_record" "kerberos_master_udp" {
  zone_id = cloudflare_zone.gensokyo-zone_zone.id
  name    = "_kerberos-master._udp"
  type    = "SRV"
  ttl     = 3600
  data {
    priority = 0
    weight   = 100
    port     = 88
    target   = local.idp_fqdn
  }
}

resource "cloudflare_record" "kerberos_tcp" {
  zone_id = cloudflare_zone.gensokyo-zone_zone.id
  name    = "_kerberos._tcp"
  type    = "SRV"
  ttl     = 3600
  data {
    priority = 0
    weight   = 100
    port     = 88
    target   = local.idp_fqdn
  }
}

resource "cloudflare_record" "kerberos_udp" {
  zone_id = cloudflare_zone.gensokyo-zone_zone.id
  name    = "_kerberos._udp"
  type    = "SRV"
  ttl     = 3600
  data {
    priority = 0
    weight   = 100
    port     = 88
    target   = local.idp_fqdn
  }
}

resource "cloudflare_record" "kerberos_txt" {
  zone_id = cloudflare_zone.gensokyo-zone_zone.id
  name    = "_kerberos"
  type    = "TXT"
  ttl     = 3600
  value   = "GENSOKYO.ZONE"
}

resource "cloudflare_record" "kerberos_uri_tcp" {
  zone_id  = cloudflare_zone.gensokyo-zone_zone.id
  name     = "_kerberos"
  type     = "URI"
  priority = 0
  data {
    weight = 100
    target = local.idp_uri_tcp
  }
  ttl = 3600
}

resource "cloudflare_record" "kerberos_uri_udp" {
  zone_id  = cloudflare_zone.gensokyo-zone_zone.id
  name     = "_kerberos"
  type     = "URI"
  priority = 0
  data {
    weight = 100
    target = local.idp_uri_udp
  }
  ttl = 3600
}

resource "cloudflare_record" "kpasswd_tcp" {
  zone_id = cloudflare_zone.gensokyo-zone_zone.id
  name    = "_kpasswd._tcp"
  type    = "SRV"
  ttl     = 3600
  data {
    priority = 0
    weight   = 100
    port     = 464
    target   = local.idp_fqdn
  }
}

resource "cloudflare_record" "kpasswd_udp" {
  zone_id = cloudflare_zone.gensokyo-zone_zone.id
  name    = "_kpasswd._udp"
  type    = "SRV"
  ttl     = 3600
  data {
    priority = 0
    weight   = 100
    port     = 464
    target   = local.idp_fqdn
  }
}

resource "cloudflare_record" "kpasswd_uri_tcp" {
  zone_id  = cloudflare_zone.gensokyo-zone_zone.id
  name     = "_kpasswd"
  type     = "URI"
  priority = 0
  data {
    weight = 100
    target = local.idp_uri_tcp
  }
  ttl = 3600
}

resource "cloudflare_record" "kpasswd_uri_udp" {
  zone_id  = cloudflare_zone.gensokyo-zone_zone.id
  name     = "_kpasswd"
  type     = "URI"
  priority = 0
  data {
    weight = 100
    target = local.idp_uri_udp
  }
  ttl = 3600
}

resource "cloudflare_record" "ldap" {
  zone_id = cloudflare_zone.gensokyo-zone_zone.id
  name    = "_ldap._tcp"
  type    = "SRV"
  ttl     = 3600
  data {
    priority = 0
    weight   = 100
    port     = 389
    target   = local.idp_fqdn
  }
}

resource "cloudflare_record" "idp-ca" {
  zone_id = cloudflare_zone.gensokyo-zone_zone.id
  name    = "idp-ca"
  type    = "CNAME"
  ttl     = 60
  value   = local.idp_fqdn
}
