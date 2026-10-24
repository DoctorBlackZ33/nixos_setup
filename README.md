# Modular NixOS and Home Manager configuration

This flake exposes two alternate NixOS configurations for the same simulated
VM hardware, plus independent standalone Home Manager configurations for
`black`. Desktop/laptop differences come from role policies. Home Manager
outputs are independent and do not read `osConfig`.

## Architecture boundaries

- `system/modules/` contains reusable NixOS policy and per-system tools.
  The `system-k3s` registry entry owns the native single-node Kubernetes service
  and its internal CNI networking; deployments choose whether to import it.
  The `system-tailscale` entry owns the native Tailscale client daemon and its
  tunnel UDP port; tailnet authorization remains an external prerequisite.
- `system/hosts/vm/` owns the shared VM hardware, host settings, login session,
  and distinct desktop/laptop host names.
- `system/accounts/` owns the NixOS OS login account; it does not define Home
  Manager identity or personal preferences.
- `home/modules/` defines typed Home Manager feature options and their guarded
  `mkIf` implementations.
- `home/profiles/` composes reusable base, desktop, and development features.
- `home/users/black/` defines the separate Home Manager target (`black`,
  `/home/black`, state version `26.05`), shared personal preferences, and a
  centralized source layout.
- `home/policies/` selects the role's clock precision, Qt format string,
  bar label, and floating-toggle chord. The label, format, and chord are
  strings; precision is a string naming the Quickshell `SystemClock` member
  emitted into QML.
- Root `flake.nix` imports explicit flake-module registries. Their
  `flake.modules` entries are reusable building blocks, not runnable hosts.
- `deployments/` consumes those registry entries to construct the runnable
  NixOS and standalone Home Manager outputs.

The desktop uses `SystemClock.Seconds`, a seconds-format clock, and
`SUPER + SPACE` to toggle floating windows. The laptop uses
`SystemClock.Minutes`, a minutes-format clock, and `SUPER + V`. The old shared
`SUPER + V` floating binding is removed and generated once from the role
policy. Both alternate hosts retain the existing VM hardware, software-rendering
settings, services, packages, and NixOS state version. The pinned inputs and
`flake.lock` are unchanged.

## Outputs

- `nixosConfigurations.desktop` (`nixos-rebuild` selector `desktop`): simulated
  desktop host named `nixos-desktop`, stock kernel, single-node k3s server,
  and Tailscale client daemon.
- `nixosConfigurations.laptop` (`nixos-rebuild` selector `laptop`): simulated
  laptop host named `nixos-laptop`, stock kernel.
- `homeConfigurations."black@desktop"`: standalone desktop Home Manager
  generation.
- `homeConfigurations."black@laptop"`: standalone laptop Home Manager
  generation.

NixOS outputs are host-only; each Home Manager output can be evaluated and
built independently. They are separate generations and activation commands.

## Evaluate and inspect

Run from `/home/black/nixos` as user `black`:

```sh
nix flake show --no-update-lock-file --no-write-lock-file path:/home/black/nixos
nix eval --json --no-update-lock-file --no-write-lock-file \
  path:/home/black/nixos#nixosConfigurations --apply builtins.attrNames
nix eval --json --no-update-lock-file --no-write-lock-file \
  path:/home/black/nixos#homeConfigurations --apply builtins.attrNames

nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#nixosConfigurations.desktop.config.networking.hostName'
nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#nixosConfigurations.laptop.config.networking.hostName'
nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#homeConfigurations."black@desktop".config.myHome.hyprland.floatingToggleChord'
nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#homeConfigurations."black@desktop".config.myHome.quickshell.clockPrecision'
nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#homeConfigurations."black@laptop".config.myHome.hyprland.floatingToggleChord'
nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#homeConfigurations."black@laptop".config.myHome.quickshell.clockPrecision'
```

Inspect the actual generated compositor loaders and Quickshell policy files:

```sh
nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#homeConfigurations."black@desktop".config.home.file.".config/hypr/hyprland.lua".text'
nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#homeConfigurations."black@laptop".config.home.file.".config/hypr/hyprland.lua".text'
nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#homeConfigurations."black@desktop".config.home.file.".config/quickshell/black/DesktopPolicy.qml".text'
nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#homeConfigurations."black@laptop".config.home.file.".config/quickshell/black/DesktopPolicy.qml".text'
```

## Build without activation

Build both exact NixOS toplevels and both independent Home Manager activation
packages. These commands do not activate either generation or update the lock
file:

```sh
nix build --no-link --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#nixosConfigurations.desktop.config.system.build.toplevel'
nix build --no-link --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#nixosConfigurations.laptop.config.system.build.toplevel'
nix build --no-link --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#homeConfigurations."black@desktop".activationPackage'
nix build --no-link --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#homeConfigurations."black@laptop".activationPackage'
```

## Use (activation is intentionally separate)

Only activate the matching profile on its intended host. NixOS activation
requires `sudo`; Home Manager runs as `black` without `sudo`:

```sh
sudo nixos-rebuild switch --flake 'path:/home/black/nixos#desktop' \
  --no-update-lock-file --no-write-lock-file
home-manager switch --flake 'path:/home/black/nixos#black@desktop' \
  --no-write-lock-file
```

Use `laptop` / `black@laptop` on the laptop host. NixOS and Home Manager
switches are independent and non-atomic. Building the outputs does not activate
either profile or prove that a graphical session can render.

## Kubernetes (desktop only)

`system/modules/k3s.nix` is registered as `flake.modules.nixos.system-k3s`.
Only `deployments/nixos.nix`'s desktop module list imports it; the laptop,
shared VM host, accounts, and standalone Home Manager outputs are unchanged.
Reuse this component by importing the registry entry in another deployment,
not by adding Kubernetes to a Home Manager profile.

The component enables native `services.k3s` as a server with its built-in
agent, containerd, Flannel VXLAN, CoreDNS, metrics-server, and local-path
storage. A fresh installation uses the default single-server SQLite datastore:
there is no `clusterInit`, external datastore, or declarative join token.
Traefik and ServiceLB are deliberately disabled: their default LoadBalancer
and hostPort/NAT rules can publish ports 80/443 independently of the host INPUT
firewall. No ingress controller or application workload is deployed here.

### Deploy and administer

On the desktop VM, with this checkout synced to `/etc/nixos`, build before
activation:

```sh
nix build --no-link --no-update-lock-file --no-write-lock-file \
  'path:/etc/nixos#nixosConfigurations.desktop.config.system.build.toplevel'
sudo nixos-rebuild switch --flake 'path:/etc/nixos#desktop' \
  --no-update-lock-file --no-write-lock-file
```

A switch applies all NixOS differences, not just k3s. Inspect unrelated drift
first; do not switch Home Manager to deploy this component. Building alone
does not start the service or prove Kubernetes readiness. After activation:

```sh
sudo systemctl status k3s
sudo journalctl -u k3s -b
sudo k3s kubectl wait node --all --for=condition=Ready --timeout=180s
sudo k3s kubectl get nodes -o wide
sudo k3s kubectl get pods -A
```

Also exercise in-pod DNS and a disposable workload/ClusterIP service, then
delete the smoke-test resources. The kubeconfig at
`/etc/rancher/k3s/k3s.yaml` is root-owned with mode `0600`; use
`sudo k3s kubectl`, which reads it automatically. It grants unrestricted
cluster administration. Do not make it world-readable or put kubeconfigs,
tokens, Kubernetes Secrets, or other credentials in this repository or Nix
expressions (the store is world-readable).

### Observed deployment verification (2026-10-24)

- Desktop and laptop NixOS toplevel builds completed; the desktop switch
  succeeded.
- Live k3s `v1.35.6+k3s1` reported `nixos-desktop` Ready, with CoreDNS,
  local-path-provisioner, and metrics-server Ready.
- The admin kubeconfig was mode `600`, owner/group `root:root`.
- Disposable BusyBox web/client pods resolved `kubernetes.default` to
  `10.43.0.1` and returned `k3s-workload-ok` over HTTP through a ClusterIP
  service. The smoke-test namespace was deleted afterward.
- From an external host, TCP 22 was reachable; TCP 6443, 10250, 80, and 443
  timed out. These checks cover the physical network, not an authorized tailnet.
- A 16 MiB local-path PVC became Bound. A writer pod wrote data and was
  deleted; an independent reader pod read the same persisted data. The
  transient storage-test namespace and workload-test namespace were removed.

### Network and access boundary

The host firewall stays enabled with its existing public TCP 22 allowance.
This component adds no public TCP/UDP allowances: API TCP 6443, kubelet TCP
10250, VXLAN UDP 8472, ingress 80/443, and NodePort ranges are not opened.
The API retains its native listener so pods can reach `kubernetes.default`;
access through physical interfaces is blocked by the host firewall, not by
binding the API to loopback. Only the internal `cni0` and `flannel.1` interfaces
are in the NixOS trusted-interface list, allowing pods to reach the node API
and kubelet. NetworkManager leaves those interfaces unmanaged; normal
reverse-path filtering remains enabled.
Trusting CNI interfaces means workloads are not isolated from host services
by this firewall.

Tailscale uses its own native netfilter rules after login; the physical
firewall boundary does not imply a tailnet boundary. See the Tailscale section
before authorizing this host.

Administer remotely through the existing SSH access, for example:

```sh
ssh -t black@192.168.122.111 sudo k3s kubectl get nodes
```

For a local kubectl client, use an SSH tunnel to server loopback TCP 6443 and
a protected `0600` kubeconfig copy with its API endpoint pointing at the
tunnel. Copied kubeconfigs need refreshing when their embedded certificates
are renewed. No direct public API opening is required.

Before adding nodes, design private, source/interface-restricted rules for
TCP 6443 to the server, UDP 8472 between Flannel nodes, and TCP 10250 between
nodes for metrics; never expose VXLAN to the internet. HA/etcd is a separate
datastore/topology change, not a reason to set `clusterInit` for this lone
server. Keep the default pod `10.42.0.0/16` and service `10.43.0.0/16` CIDRs
clear of host/VPN networks. To opt into bundled ingress later, deliberately
change the component's `disable` list and review ServiceLB/Traefik exposure.
User-created NodePort, LoadBalancer, and hostPort workloads can install NAT
and forwarding rules that bypass the host INPUT firewall; review them before
deployment rather than assuming the host port list is a workload perimeter.

### State and operational lifecycle

K3s keeps runtime state, images, certificates, and generated join credentials
under `/var/lib/rancher/k3s`; SQLite is in `server/db/`, its required restore
token is `server/token`, and local-path volume data defaults to `storage/`
under that directory. Back up the database consistently (quiesce/stop writes
before copying), the matching token, and application volume data separately.
There is no automatic backup or HA in this component; a VM outage loses the
only control plane and workload node.

NixOS rebuilds and generation rollbacks do not roll back Kubernetes resources,
database migrations, or persistent volume contents. Disabling/removing the
component does not erase cluster data. The native unit uses
`KillMode=process`, so stopping the service alone can leave containers running;
plan an explicit workload/runtime teardown before retiring the cluster, and
only remove state after a deliberate backup/data-loss decision. Do not use
the upstream shell installer/uninstaller to manage this NixOS-owned service.
Initial startup needs outbound DNS/registry access to pull images, available
disk/RAM, and functioning CNI routing; confirm node/pod/DNS/workload health
after deployment and before relying on the cluster.

References: [pinned NixOS k3s module](https://github.com/NixOS/nixpkgs/blob/21ea275a7c46aef9d4d6ddc962e6d562e9d94183/nixos/modules/services/cluster/rancher/k3s.nix),
[shared native service implementation](https://github.com/NixOS/nixpkgs/blob/21ea275a7c46aef9d4d6ddc962e6d562e9d94183/nixos/modules/services/cluster/rancher/default.nix),
[k3s networking requirements](https://docs.k3s.io/installation/requirements#networking),
[packaged networking services](https://docs.k3s.io/networking/networking-services),
[cluster access](https://docs.k3s.io/cluster-access), and
[SQLite backup/restore](https://docs.k3s.io/datastore/backup-restore).

## Tailscale (desktop only)

`system/modules/tailscale.nix` is registered as
`flake.modules.nixos.system-tailscale` and imported only by the desktop in
`deployments/nixos.nix`. Other deployments can opt in through that registry
entry. Laptop, Home Manager, accounts, and the k3s component are unchanged.

The component sets native `services.tailscale.enable = true` and
`services.tailscale.openFirewall = true`. The pinned module installs the
`tailscale` CLI, enables `tailscaled.service` at boot, and opens only its tunnel
UDP port (native default `41641`). It retains the native `tailscale0` interface,
`useRoutingFeatures = "none"`, `authKeyFile = null`, and empty extra flag lists.
It adds no subnet/exit-node settings, Tailscale SSH, forwarding sysctls, relaxed
reverse-path filtering, or NixOS trusted interfaces. Normal client defaults
apply, including tailnet DNS; on a fresh Linux client subnet-route acceptance
and Tailscale SSH are off. Existing daemon preferences are not reset by a
NixOS rebuild.

### Activate and authorize

Sync the checkout to `/etc/nixos` on the desktop, then build and activate as
shown in the Kubernetes deployment section. A switch deploys both components;
do not switch Home Manager or the laptop to deploy Tailscale. After activation:

```sh
sudo systemctl status tailscaled
sudo journalctl -u tailscaled -b
tailscale status
sudo tailscale up
```

A running daemon is not proof of tailnet authorization. On a fresh deployment,
`tailscale status` reports that login is needed; there is no tailnet connectivity
before authorization. Open the URL printed by `sudo tailscale up` and log in
with the intended Tailscale account. A tailnet administrator may also need to
approve the device. No auth key is configured and no automatic login is
attempted. Do not add auth keys, daemon state, or generated credentials to this
repository or Nix expressions: the Nix store is world-readable.

After the account owner completes authorization, inspect:

```sh
tailscale status
tailscale ip -4
tailscale netcheck
```

Confirm the intended device/account in the Tailscale admin console and test
the specific peer/application path you need; daemon health alone is not an
end-to-end connectivity check. `sudo tailscale down` disconnects without
logging out; `sudo tailscale logout` requires a new login before reconnecting.
Keep the existing non-Tailscale SSH path available while administering access.

### Observed deployment verification (2026-10-24)

- The combined desktop and laptop NixOS toplevel builds completed; the desktop
  switch succeeded, with both `tailscaled` and `k3s` active.
- Tailscale reported version `1.98.10`. `tailscale up --timeout=15s` produced an
  account authorization URL and then timed out while awaiting login. The URL
  was provided to the account owner, not recorded in this repository.
- Native status remained `BackendState = NeedsLogin` with no `TailscaleIPs`.
  Account authorization is still required; tailnet connectivity and
  end-to-end peer access remain unverified pending login.
- After Tailscale activation, the k3s node remained Ready and CoreDNS,
  local-path-provisioner, and metrics-server remained Running.

### Firewall and tailnet policy

The NixOS firewall remains enabled; this component adds only UDP `41641` and
does not add `tailscale0` to `networking.firewall.trustedInterfaces`. However,
native Tailscale netfilter mode remains `on`: `tailscaled` installs rules that
accept tailnet traffic ahead of the NixOS INPUT chain. Not trusting the
interface in NixOS therefore does **not** block authenticated tailnet peers
from listening host services, including the k3s API and kubelet.

Before authorizing this node, review the tailnet's access policy. Tailnet
grants/ACLs must restrict who can reach the desktop and its ports; do not assume
the physical-interface firewall test also protects the tailnet. This component
does not install a tailnet policy, change native netfilter behavior, advertise
cluster routes, or grant Kubernetes credentials. Tailnet reachability does
not itself grant Kubernetes authorization.

References: [pinned native NixOS module](https://github.com/NixOS/nixpkgs/blob/21ea275a7c46aef9d4d6ddc962e6d562e9d94183/nixos/modules/services/networking/tailscale.nix),
[Tailscale CLI](https://tailscale.com/docs/reference/tailscale-cli),
[firewall connectivity](https://tailscale.com/docs/reference/faq/firewall-ports),
and [native netfilter behavior](https://tailscale.com/docs/reference/netfilter-modes).

## VM display and startup lifecycle

The VM's persistent display hardware belongs to its libvirt domain, not this
NixOS/Home Manager flake. The `virtualisation.vmVariant` settings in
`system/hosts/vm/hardware.nix` configure the `nixos-rebuild build-vm` output;
they do not add or change PCI devices in an already-defined libvirt domain.
The libvirt domain must attach a video device (virtio GPU) and expose a
host-only graphical console. `hardware.graphics.enable` and software-rendering
environment variables configure the guest's software stack, but cannot create
missing display hardware.

On boot, system-level greetd starts tuigreet on `tty1` with
`start-hyprland` as the post-authentication command. Hyprland starts only after
the user authenticates; Quickshell is not expected at the greeter. The
independent Home Manager profile installs the generated Hyprland Lua loader,
Quickshell config, and the startup hook that runs
`quickshell --config black` once Hyprland starts. A NixOS switch does not
activate Home Manager; switch `black@desktop` separately before logging into
the graphical session.
