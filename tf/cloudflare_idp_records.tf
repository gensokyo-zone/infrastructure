resource "cloudflare_record" "kerberos_master_tcp" {
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  name = "_kerberos-master._tcp"
  type = "SRV"
  ttl = 3600
  data {
    service = "_kerberos-master"
    proto = "_tcp"
    name = "gensokyo.zone."
    priority = 0
    weight = 100
    port = 88
    target = "idp.gensokyo.zone."
  }
}

resource "cloudflare_record" "kerberos_master_udp" {
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  name = "_kerberos-master._udp"
  type = "SRV"
  ttl = 3600
  data {
    service = "_kerberos-master"
    proto = "_udp"
    name = "gensokyo.zone."
    priority = 0
    weight = 100
    port = 88
    target = "idp.gensokyo.zone."
  }
}

resource "cloudflare_record" "kerberos_tcp" {
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  name = "_kerberos._tcp"
  type = "SRV"
  ttl = 3600
  data {
    service = "_kerberos"
    proto = "_tcp"
    name = "gensokyo.zone."
    priority = 0
    weight = 100
    port = 88
    target = "idp.gensokyo.zone."
  }
}

resource "cloudflare_record" "kerberos_udp" {
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  name = "_kerberos._udp"
  type = "SRV"
  ttl = 3600
  data {
    service = "_kerberos"
    proto = "_udp"
    name = "gensokyo.zone."
    priority = 0
    weight = 100
    port = 88
    target = "idp.gensokyo.zone."
  }
}

resource "cloudflare_record" "kerberos_txt" {
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  name = "_kerberos"
  type = "TXT"
  ttl = 3600
}

resource "cloudflare_record" "kerberos_uri_tcp" {
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  name = "_kerberos"
  type = "URI"
  data {
    priority = 0
    weight = 100
    target = "krb5srv:m:tcp:idp.gensokyo.zone."
  }
  ttl = 3600
}

resource "cloudflare_record" "kerberos_uri_udp" {
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  name = "_kerberos"
  type = "URI"
  data {
    priority = 0
    weight = 100
    target = "krb5srv:m:udp:idp.gensokyo.zone."
  }
  ttl = 3600
}

resource "cloudflare_record" "kpasswd_tcp" {
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  name = "_kpasswd._tcp"
  type = "SRV"
  ttl = 3600
  data {
    service = "_kpasswd"
    proto = "_tcp"
    name = "gensokyo.zone."
    priority = 0
    weight = 100
    port = 464
    target = "idp.gensokyo.zone."
  }
}

resource "cloudflare_record" "kpasswd_udp" {
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  name = "_kpasswd._udp"
  type = "SRV"
  ttl = 3600
  data {
    service = "_kpasswd"
    proto = "_udp"
    name = "gensokyo.zone."
    priority = 0
    weight = 100
    port = 464
    target = "idp.gensokyo.zone."
  }
}

resource "cloudflare_record" "kpasswd_txt" {
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  name = "_kpasswd"
  type = "TXT"
  ttl = 3600
}

resource "cloudflare_record" "kpasswd_uri_tcp" {
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  name = "_kpasswd"
  type = "URI"
  data {
    priority = 0
    weight = 100
    target = "krb5srv:m:tcp:idp.gensokyo.zone."
  }
  ttl = 3600
}

resource "cloudflare_record" "kpasswd_uri_udp" {
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  name = "_kpasswd"
  type = "URI"
  data {
    priority = 0
    weight = 100
    target = "krb5srv:m:udp:idp.gensokyo.zone."
  }
  ttl = 3600
}

resource "cloudflare_record" "ldap" {
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  name = "_ldap._tcp"
  type = "SRV"
  ttl = 3600
  data {
    service = "_ldap"
    proto = "_tcp"
    name = "gensokyo.zone."
    priority = 0
    weight = 100
    port = 389
    target = "idp.gensokyo.zone."
  }
}

resource "cloudflare_record" "idp-ca" {
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  name = "idp-ca"
  type = "CNAME"
  ttl = 60
  value = "idp.gensokyo.zone."
}