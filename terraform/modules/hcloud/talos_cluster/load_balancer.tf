resource "hcloud_load_balancer" "load_balancer" {
  name               = "gateway-shared"
  load_balancer_type = "lb11"
  location           = "nbg1"
}
