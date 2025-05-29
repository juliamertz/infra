resource "cloudflare_dns_record" "a_records" {
  for_each = var.records

  name    = each.value.domain_suffix ? "${each.value.name}.${var.domain}" : each.value.name
  content = each.value.content != null ? each.value.content : var.default_content
  ttl     = each.value.ttl != null ? each.value.ttl : 300
  proxied = each.value.proxied != null ? each.value.proxied : false

  type     = each.value.type
  priority = each.value.priority
  zone_id  = var.zone_id
}
