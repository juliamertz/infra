# Prerequisites

This repo uses [direnv]() extensively to make things work, make sure you have it installed
Deployment secrets are handled with [sops]() make sure this is set up

# Bugs / Manual deployment steps:

- [ ] key won't match when server is destroyed and created, we have to sed out the lines in fix gatekeeper not automatically adding ip route for floating ip
    - temporary fix: `ip addr add <floating-ip>/32 dev eth0`
    - maybe just do this as a terraform step, although hacky it does give us the benefit of knowing the ip
    - does it persist with rebuilds/network restarts though?
