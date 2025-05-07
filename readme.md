# Bugs / Manual deployment steps:

- [ ] fix gatekeeper still asking for confirmation to trust host key on terraform deploy
    - this might be fixed by using a proper deployment tool like colmena
- [ ] fix gatekeeper not automatically adding ip route for floating ip
    - temporary fix: `ip addr add <floating-ip>/32 dev eth0`
    - maybe just do this as a terraform step, although hacky it does give us the benefit of knowing the ip
    - does it persist with rebuilds/network restarts though?
- [ ] set static ip assignments within hetzner subnet

# TODO:

- [ ] add solution for easily sharing variables between nix and terraform (maybe include terraform outputs)
    - maybe wrap tofu with vars?

# Prerequisites

- `/etc/hosts`
    Set up aliases for the internal wireguard network
    ```
    10.100.0.1 main
    10.100.0.2 gatekeeper
    ```

