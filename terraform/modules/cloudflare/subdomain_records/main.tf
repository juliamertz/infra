resource "cloudflare_dns_record" "a_records" {
  for_each = var.records

  name     = "${each.value.name}.${var.domain}"
  type     = each.value.type
  content  = each.value.content != null ? each.value.content : var.default_content
  ttl      = each.value.ttl != null ? each.value.ttl : 300
  proxied  = each.value.proxied != null ? each.value.proxied : false
  priority = each.value.priority 

  zone_id = var.zone_id


  lifecycle {
    ignore_changes = [
      meta,
      proxiable,
      settings,
      tags,
      comment,
      comment_modified_on,
      tags_modified_on
    ]
  }
}

