# Network Module — Design Document

**Status**: Future work (not yet implemented)

## Overview

The network verification subsystem will provide integrity checking for
network configuration and state. This includes:

- Routing table verification against declared policy
- Firewall rule attestation (iptables/nftables state matches policy)
- TLS certificate chain verification with expiry tracking
- DNS resolution integrity (DNSSEC validation)

## Planned Modules

| Module                         | Purpose                                 |
|--------------------------------|-----------------------------------------|
| `Ochrance.Network.Types`       | Core types (routes, rules, certs)       |
| `Ochrance.Network.Routing`     | Routing table verification              |
| `Ochrance.Network.Firewall`    | Firewall rule attestation               |
| `Ochrance.Network.TLS`         | Certificate chain verification          |
| `Ochrance.Network.DNS`         | DNS resolution integrity                |

## Verification Modes

- **Lax**: Check that routing table and firewall rules are non-empty
- **Checked**: Verify rule hashes against declared policy manifest
- **Attested**: Full policy graph verification with reachability proofs

## Dependencies

- Requires `Ochrance.Framework.*` (core interface and proof types)
- Requires the `network` Idris2 package for socket types
- FFI to C for reading netlink sockets and nftables state
- May depend on `Ochrance.Filesystem.*` for reading `/etc/` config files

## Open Questions

- How to model dynamic routing (OSPF/BGP) state that changes frequently?
- Should TLS verification use system trust store or a bundled CA set?
- Integration with systemd-networkd or NetworkManager state?
