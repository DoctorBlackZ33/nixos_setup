# Recommended architecture and plan

Companion to `AUDIT.md` (what was wrong) and `nixos-architecture-spec-v3.md`
(what the code must do). This file says what I would build on from here, in
which order, and what I would leave alone.

## 1. Recommendation

Keep the shape the repository has now and stop adding machinery. The structure
is sufficient for 10+ mixed hosts; what is missing is operational: installing
hosts, rolling out, real keys, CI. Spend the next effort there.

Three structural changes are still worth making, all small:

1. **Accounts belong to the user.** A login is declared once in
   `users/<user>/account.nix` and applied on every NixOS host the user is
   deployed to. Today each hostConf repeats it.
2. **One updatable nixpkgs.** Replace the fixed release tarball with a branch
   reference, keep one channel for every host, and take newer packages on
   workstations through an overlay.
3. **The spec lives in the repository** (`docs/spec.md`), so it is versioned
   with the code it describes.

## 2. Target picture

```mermaid
flowchart TB
  subgraph Conf[config flake: values]
    INV[deployments.nix<br/>who runs where, deploy target]
    HOSTS[hosts/&lt;host&gt;<br/>facts, report, disks, hostConf]
    USERS[users/&lt;user&gt;<br/>account, profiles]
    SEC[secrets/]
  end
  subgraph Mod[framework flake: mechanism]
    FLEET[fleet builder]
    HOME[home modules]
    SYS[system modules + providers]
    CON[contract + reconcile]
    AD[adapters]
  end
  INV --> FLEET
  HOSTS --> FLEET
  USERS --> FLEET
  FLEET --> AD
  HOME --> AD
  SYS --> AD
  CON --> AD
  SEC --> SYS
  AD --> N[nixosConfigurations]
  AD --> S[systemConfigs]
  AD --> H[hjemConfigurations]
  N --> CHK[one check per deployment]
  S --> CHK
  H --> CHK
  CHK --> CI[builder + binary cache]
  CI --> ROLL[rollout: test, verify, switch]
```

## 3. Decisions

| Topic | Recommended | Not recommended | Revisit when |
|---|---|---|---|
| Repository shape | Framework stays a subflake of this repository | Separate framework repository now | A second config repository needs it; then tag releases and pin a tag |
| User layer delivery | Hjem: its NixOS module, and `hjem standalone` elsewhere | Home Manager next to Hjem | Hjem's standalone format changes incompatibly or the project stalls. The backend is confined to `adapters/hjem.nix` and `adapters/standalone.nix` |
| Non-NixOS system layer | `managed = "manual"` by default | system-manager on every foreign host | A foreign host needs a system service or account managed from here. Its option set is small and its firewall module is a mock |
| Capabilities on non-NixOS hosts | Declared by hand, plus a `doctor` script that checks them on the machine | Trusting the declaration | — |
| Contract scope | Only what crosses from user to system, and host refusal | Routing system-internal needs through it; a generic contract framework | A kind has a consumer, a provider and a check |
| Secrets on NixOS | agenix + agenix-rekey, YubiKey master, 1Password recipient, offline key | A second secrets tool | — |
| Secrets for standalone users | The 1Password agent and CLI on that machine | A decrypt backend in the user layer | Two standalone users need the same repo-managed secret |
| Installing a host | nixos-anywhere + disko + nixos-facter (`--generate-hardware-config nixos-facter`) | Hand-written hardware files for new hosts | — |
| Hardware configuration | `hardware.facter.reportPath` on new installs; existing hosts keep their files | Switching running hosts to it without a reason | A host is reinstalled |
| Rollout | `nixos-rebuild test --target-host`, check SSH, then `switch`, driven by a short script over the inventory | An own deployment tool | About 15 hosts, or parallel rollout matters: colmena. Unattended remote hosts: deploy-rs for automatic rollback |
| nixpkgs | One stable branch for all hosts (`github:NixOS/nixpkgs/nixos-26.05`); unstable packages through an overlay | A nixpkgs per deployment | A host needs a newer NixOS release as a whole. system-manager's branch must then move with it |
| CI | One builder; one job per check attribute (`nix-fast-build` or `nix build .#checks.<system>.<name>`) | One aggregate job | — |
| Binary cache | harmonia on a server; hosts substitute from it | Every host building for itself | — |
| Other architectures | Evaluate anywhere (already true); build on a native builder or with emulation on the builder | Cross-compiling systems | — |
| Runtime tests | Two NixOS VM tests: workstation login path with Hjem files, server with a secret (owner and mode) | Relying on evaluation for runtime behaviour | — |
| Services spanning hosts (backups, mesh VPN, monitoring) | Nothing until the second one exists | Roles on machines; a service engine now | Two such services are wanted: adopt clan, or instances with roles assigned by `tags` |
| Server baseline | The small own module; copy single settings from srvos when needed | Importing srvos wholesale (it decides sudo policy and more) | — |
| Style | alejandra, statix, deadnix as checks | Formatting by convention | — |

The packages named above (nixos-anywhere, disko, nix-fast-build, statix,
deadnix, colmena, deploy-rs) and the `services.harmonia` option exist in the
pinned nixpkgs; `/dev/kvm` is available in the guest for VM tests.

## 4. Plan

Each phase ends with something observable. Phases 1 to 3 are prerequisites
for real hosts; the rest can be reordered.

### Phase 0 — done (commit `d99f9e8`)

Provider-based contract, typed inventory and facts, NixOS / system-manager /
standalone delivery, per-deployment checks, synthetic fleet, opt-in secrets
provider, reference workstation and server.

### Phase 1 — foundations for real hosts

- `users/<user>/account.nix` (description, shell, authorized keys, uid) applied
  automatically where the user is deployed on NixOS; hostConf adds groups only.
- `deploy.targetHost` (and optional `buildHost`) per deployment in the
  inventory.
- nixpkgs as a branch reference in both flakes; unstable overlay for
  workstations.
- Spec moved to `docs/spec.md`; statix and deadnix checks; formatter run once.
- Exit: a new NixOS host needs `facts.nix`, `default.nix` and one inventory
  line, with no account text; `nix flake update nixpkgs` moves every host.

### Phase 2 — first real NixOS server

- Disk layout with disko in `hosts/<host>/disks.nix`.
- Install with nixos-anywhere, generating `facter.json`; enable
  `hardware.facter.reportPath` for this host.
- Key-only SSH; no password hash.
- Rollout script: build, `test` on the target, confirm SSH, `switch`.
- Exit: the server was installed from this repository and rebuilt once through
  the script.

### Phase 3 — secrets with real keys

- YubiKey identity stub, 1Password recipient, offline key; set
  `framework.secrets`; `hostKey` for each NixOS host.
- First consumer: account passwords through `hashedPasswordFile`.
- NixOS VM test asserting owner and mode of a decrypted secret.
- Written procedures: lost YubiKey, reinstalled host, compromised host,
  retiring a host.
- Exit: no secret-derived value in the store on real hosts; one rekey done and
  one recovery rehearsed with the offline key.

### Phase 4 — real workstations

- Desktop and laptop as real hosts with their own reports and overrides.
- NixOS VM test: greeter starts the compositor session; Hjem files exist and
  belong to the user.
- Exit: both run from this repository; the `desktop`/`server` references for
  the libvirt guest are kept only as test targets or removed.

### Phase 5 — non-NixOS machines

- The Arch workstation as a `manual` host; `hjem standalone switch` on it.
- `doctor` script generated from the host's declared capabilities.
- Build-time check running `hjem standalone switch --manifest` into a
  temporary home, so a Hjem upgrade that breaks linking fails in CI.
- Exit: switch and rollback done on the real machine; `doctor` passes there.

### Phase 6 — CI and cache

- Builder with one job per check; harmonia cache; hosts configured to use it.
- Scheduled `nix flake update` with the checks as gate.
- Exit: a push builds every deployment; a rollout downloads instead of
  building.

### Phase 7 — services across hosts (only when needed)

- Decide between clan and own instances when the second multi-host service is
  wanted. The inventory already keeps tags on machines and no roles, which is
  the shape both use.

### Phase 8 — framework repository (only when needed)

- Split out when a second config repository exists; version it; the config
  flake pins a tag and keeps running the framework checks against its own
  lock.

## 5. What I would not build

- A nixpkgs per deployment.
- A generic contract or dependency framework; more capability kinds than have
  consumers.
- A secrets backend for standalone users.
- A deployment tool beyond a short script.
- Machine-level roles or a service engine before two multi-host services
  exist.
- A program-per-flake split.

## 6. Risks and what guards against them

| Risk | Guard |
|---|---|
| Hjem is young and its standalone CLI is new | Pinned revision; backend in two adapter files; the Phase 5 build-time check |
| system-manager must match the nixpkgs release | One nixpkgs for all hosts; its branch is updated together with nixpkgs |
| A capability declared by hand on a foreign host does not exist | `doctor` script on the machine; until then treat the declaration as documentation |
| A remote rebuild cuts off access | `test` before `switch`; a reboot returns to the previous generation |
| Loss of the YubiKey | 1Password recipient and offline key; rehearsed in Phase 3 |
| Old ciphertext stays readable to an old key | Rotation means changing the credential; procedure written in Phase 3 |
| Evaluation time grows with the fleet | Checks are per deployment and can run as separate jobs; measure at 10 hosts before changing anything |
| Documentation drifts from code | Spec in the repository; README commands are the check commands |
