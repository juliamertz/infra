resource "cloudflare_dns_record" "records" {
  for_each = var.records

  zone_id  = var.zone_id

  name = each.value.name == "@" || each.value.name == "" ? var.domain : (
    each.value.domain_suffix ? "${each.value.name}.${var.domain}" : each.value.name
  )

  type     = each.value.type
  priority = each.value.priority

  content = format(
    each.value.type == "TXT" ? "\"%s\"" : "%s",
    coalesce(each.value.content, var.default_content)
  )

  ttl     = coalesce(each.value.ttl, var.ttl)
  proxied = coalesce(each.value.proxied, var.proxied)
}
