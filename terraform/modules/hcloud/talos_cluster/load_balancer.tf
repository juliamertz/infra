# resource "hcloud_load_balancer" "load_balancer" {
#   name               = "gateway-shared"
#   load_balancer_type = "lb11"
#   location           = "nbg1"
# }
#
# resource "hcloud_load_balancer_service" "service_http" {
#   load_balancer_id = hcloud_load_balancer.load_balancer.id
#   protocol         = "tcp"
#   listen_port = 80
#   destination_port = 30080
#   proxyprotocol = false
# }
#
# resource "hcloud_load_balancer_service" "service_https" {
#   load_balancer_id = hcloud_load_balancer.load_balancer.id
#   protocol         = "tcp"
#   listen_port = 443
#   destination_port = 30443
#   proxyprotocol = false
# }
