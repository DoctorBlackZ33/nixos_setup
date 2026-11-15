# Audit of the first spec implementation (commit 2b6de3e)

Scope: the repository as committed in `2b6de3e`, checked against
`nixos-architecture-spec.md` (v2) and against a fleet of 10+ machines mixing
workstations and servers, NixOS and non-NixOS hosts, two architectures.
Every "bad" entry below was reproduced on the VM or read in the code; every
"fixed" entry is covered by a check or was run by hand (section 5).

## 1. What was broken, in short

- **The adapter did the providers' job.** One NixOS adapter knew six services
  by name, enabled them and computed what the host provides. Hosts had no say.
- **Requirements lost their owner.** They were merged with `//`, so the last
  user won and no error could say who asked.
- **The inventory was code, and partly ignored.** `deployments.nix` contained
  the builders; the `adapter` field was not honoured; checks listed host names
  by hand.
- **The portability claim was false.** The `facts.managed == "nixos"` gates do
  not make a module loadable under system-manager, and no system-manager or
  activating standalone path existed.
- **Evaluation needed builds.** Two modules read generated TOML back, which
  breaks strict evaluation and any host of another architecture.
- **General modules held personal values.** An editor configuration, a login
  name, a checkout path, a time zone.
- **Facts could not fail.** Defaults such as `gpu.vendor = "unknown"` satisfied
  every requirement, and the two adapters saw differently shaped facts.

## 2. Findings and fixes

### Contract and adapters

| # | What was bad | Case that breaks | How it is fixed |
|---|---|---|---|
| 1 | Service table, fulfilment and `provides` inside `adapters/nixos.nix` | Every new capability edits the adapter; `services.printing.enable = true` still reported "cups not provided" | Provider modules in `framework/system/nixos` enable and report (`desktop.nix`, `audio.nix`, `pam.nix`); adapters only translate |
| 2 | A host could not refuse a capability | `black` on a server switched on Hyprland, portals, PipeWire and fonts there (169 instead of 153 system packages) | Providers offer only where `sysMod.desktop.enable` / `sysMod.audio.enable` is true (default: workstations); the request stays unmet and fails with the user's name |
| 3 | `requires` merged with `//` | User A requires `cups`, user B marks it optional: merged result optional, no error; same for a secret's mode | Requests are kept per source; one requester needing it makes it required; differing parameters are an error naming each requester |
| 4 | Errors without provenance | "requires service 'x'" on a host with several users | `service 'x' is requested by user carol but host 'nas' does not provide it` |
| 5 | `config.provides` was not the value that was reconciled | The documented inspection command showed hand-written data | One option, written by providers from their own config |
| 6 | Portal reported as provided with `xdg.portal.enable = false`; a gnome-only request configured the absent gtk backend as default | Contract passes, portal does not work | Provider reports `enable && installed`; the default backend is taken from what is installed |
| 7 | Capability shape repeated in 8 places; `portals` a list, others attrsets; `udev` and `setuid` without consumer or provider | Adding a kind touched 3 files / 10 sites | One table (`lib/capabilities.nix`); uniform `<kind>.<name> = { required; … }`; unused kinds removed |
| 8 | Facts with invented defaults; `false` counted as present | `requires.facts."gpu.vendor"` could never fail | `null` = unknown; unknown, `false` and empty all count as missing |
| 9 | Facts typed on NixOS, raw on standalone | `facts.gpu.vendor` evaluated on one adapter and threw on the other | One typed value for every adapter (`lib/facts.nix`); `facter.json` fills gaps, hand-written facts win |
| 10 | Typos in hand-written `provides` were dropped silently | `service.hyprland = true` (missing `s`) | Hand-written data goes through the same types; unknown kinds fail |
| 11 | Standalone adapter: no activation, warnings never shown | Goal 3 of the spec unmet | Returns the value `hjem standalone switch` consumes; errors throw, warnings are emitted |
| 12 | No system-manager adapter; `mkIf` gates claimed to prepare for it | Any NixOS-only option fails under system-manager even behind `mkIf false` | Modules split by class (`system/common`, `system/nixos`); system-manager adapter added |
| 13 | Hjem directory forced to `/home/<user>` | An account with another home got files in the wrong place | Hjem's own default (the account's home) is used |
| 14 | A fixed-point cycle and an eagerly forced condition were worked around but undocumented | Silent empty requirements | Kept apart in `hjem-register.nix` / `nixos-users.nix`; rules written down in `reference.md` section 3 |

### Inventory and checks

| # | What was bad | Case that breaks | How it is fixed |
|---|---|---|---|
| 15 | Builders lived in the config flake | Framework checks could not exercise the real code path | `framework/lib/fleet.nix` + a flake module; `deployments.nix` is data |
| 16 | `adapter` field ignored for standalone outputs; a typo made a host vanish | `adapter = "nixso"`: no output, no error | Field removed; `facts.managed` selects the adapters |
| 17 | Mandatory `hosts/<host>/users/<user>.nix` | Every host needed an empty file per user | Optional |
| 18 | `checks.nix` listed `[ "desktop" "laptop" ]` and `x86_64-linux` | A third host failed the check; a fleet of servers failed it too | One generated check per deployment, for its own platform |
| 19 | One aggregate check evaluated all hosts and built none | 2 hosts 7.7 s / 1.8 GiB, 6 hosts 19.7 s / 4.6 GiB in one evaluation; no build | Per-deployment checks are the system toplevels; each can be evaluated or built alone |
| 20 | Standalone packages built for every listed system, not the host's | Adding `aarch64-linux` produced ARM outputs for x86 hosts | Each host is built with the packages of `facts.platform` |
| 21 | No validation of names | Unknown host or user: a path error at best | Unknown host/user, duplicate user, stray `homes` entry, wrong files for the host's `managed` value, duplicate host names: one message listing valid names |
| 22 | A deployed user without an account | NixOS error about `isNormalUser` | Assertion naming host, user and the option to set |
| 23 | Host config could disagree with facts | Checks filed under the wrong platform or name | Facts are read-only; host name and platform are asserted equal to them |

### User layer

| # | What was bad | Case that breaks | How it is fixed |
|---|---|---|---|
| 24 | `builtins.readFile` of generated TOML (yazi, direnv) | `--option allow-import-from-derivation false` fails; an aarch64 host cannot be evaluated on x86_64 | `source = format.generate …`; whole tree evaluates without builds |
| 25 | Every program had `settings = attrsOf anything` and text sections | `fish.settings.alaises` was accepted and ignored | Typed options; `pkgs.formats` types for structured files |
| 26 | INI defaults concatenated as text with user settings | Duplicate keys instead of overrides; fuzzel rejected its file (`[main].background: not a valid option`) | Settings are merged values; the generated `fuzzel.ini` passes `fuzzel --check-config` |
| 27 | 200 lines of personal editor settings, `/home/black/experimental` and `nixosConfigurations.desktop` inside `framework/home/nvf.nix`; a broken option expression | Any second user, host or checkout | Module reduced to the bridge; values in `users/black/nvim.nix`, derived from `facts.name` |
| 28 | Taste defaults in general modules (colours, `--cmd=cd`, key chord) | Second user inherits them | Moved to `users/black` |
| 29 | Quickshell required PipeWire although its bar does not use it | Refused on hosts without audio for no reason | Requirement removed |
| 30 | Files only under `~/.config`; any key accepted | Nothing outside `.config`; `../x` or `/etc/x` possible | Paths relative to the home directory, validated |
| 31 | Section order by magic numbers and offsets; no way to drop a section | `integrations + 200` | Named scale matching `lib.mkOrder`; sections can be replaced or disabled by name |
| 32 | User profile was unconditional | Desktop packages and editor on every host | Profiles in `users/black` gate on `facts.kind` |
| 33 | Three copies of the module discovery, plus a hand-written list | A new file was imported but not exported | One function (`lib/modules.nix`) |

### System layer

| # | What was bad | Case that breaks | How it is fixed |
|---|---|---|---|
| 34 | Compilers and language servers on every host | Servers | `sysMod.development.enable`, off by default |
| 35 | NetworkManager and port 22 on every host | Servers | Backend follows `facts.kind`; sshd on servers by default |
| 36 | Greeter ran as `black`; empty command accepted | Login prompt as the user; `tuigreet --cmd ` with nothing | Runs as `greeter`; assertion when there is nothing to start |
| 37 | Time zone default in the framework | Second location | No default; hosts set it; servers default to UTC |
| 38 | Fish enabled by the development module because one account uses it | Hidden coupling | Accounts name their shell; the matching program is enabled |
| 39 | Password hash as the only way to set a password; password SSH everywhere | Real hosts | `hashedPasswordFile` and `authorizedKeys`; key-only sshd on servers; a key-only sshd nobody can log into is refused. The reference hosts keep the password because they are a throwaway guest |
| 40 | Secrets: a contract type that accepted `provides.secrets.x = true` | Reconcile passed without any secret existing | agenix provider (opt-in), path interface, one reader per secret, no secrets off NixOS |

### Documentation

| # | What was bad | How it is fixed |
|---|---|---|
| 41 | README said the `mkIf` gates prepare for system-manager, and described checks and inspection commands that did not match the code | Rewritten from the code; commands in it were run |
| 42 | `reference.md` carried a dated "verification performed" list | Removed; it now lists the module-system traps instead |
| 43 | `.gitignore` ignored `secrets/`, which the spec wants committed | Entry removed |

## 3. Growing to 10+ mixed machines

| Change | Before | Now |
|---|---|---|
| Add a NixOS host | `hosts/H/{default,facts}.nix`, inventory, check whitelist, one override file per user | `hosts/H/{facts,default}.nix`, one inventory line |
| Add a user to a host | userConf, mandatory override, inventory, account | inventory, account (asserted); override optional |
| Add a fulfillable capability | adapter enable rule + adapter report | one provider module |
| Add a capability kind | 3 files, 10 sites | one table entry + provider |
| Add a system-manager host | not possible | `facts.nix`, `default.nix`, inventory line |
| Add a manual host | facts with hand-written provides, mandatory overrides | `facts.nix`, optional `provides.nix`, inventory line |
| Add an architecture | wrong-platform outputs, checks blind to it | follows `facts.platform`; evaluates from any machine |

The synthetic fleet (`framework/checks/fleet`) keeps this honest: 13 hosts
(7 NixOS incl. one aarch64, 3 system-manager, 3 manual) go through the same
builder as the real inventory. It asserts, among others: a server stays
headless; a gated desktop user is harmless on a server; an ungated one is
refused on NixOS, system-manager and manual hosts with a message naming user
and host, without blocking other users of that host; files, packages and
environment reach Hjem; standalone files land in the configured home; inventory
mistakes are rejected.

## 4. Review addendum (Astra)

The plan and spec v3 were reviewed by an independent planning agent before the
commit. It accepted the design and required changes; all "must" items are in.

| Required | Done as |
|---|---|
| Locks behind the code; framework checks ran against another lock | Both locks carry the same revisions; the root flake runs the framework checks itself (`framework-*`) |
| Unused inventory values accepted | `homes` for unlisted users, relative homes, `homes` on NixOS hosts, duplicate users are rejected |
| Facts and system identity could diverge | Facts read-only; host name and platform asserted |
| Tests looked at the module, not at what is delivered | Checks read Hjem's files, packages and environment, and the standalone manifest |
| Shared secret unreadable by both requesters | A secret has exactly one reader; a second requester is an error |
| Secrets could be claimed on hosts without a backend | Rejected on manual and system-manager hosts |
| Secrets provider sat among the adapters | Moved to `framework/system/optional` |
| Activation tools from a moving branch | `packages.{hjem,system-manager,agenix}` at the locked revisions |
| "No invented defaults" contradicted by `refresh = 60` | Unknown refresh is `null` |
| Verification should reach activation | `hjem standalone switch`, stale-link removal, rollback and the real `agenix rekey` → decrypt chain were run (section 5) |

A second, confirmation pass on the corrected spec and the final tree found
seven of nine corrections applied and two partly, plus four leftovers. All six
were fixed before the commit:

| Found | Fixed as |
|---|---|
| "One reader per secret" only held once the ciphertext existed | Asserted for every request as soon as the provider is on |
| On a system-manager host one user's unmet request stopped the system, and with it every other user | A system judges only what is evaluated inside it; standalone users get their verdict in their own configuration |
| Fonts chosen by the desktop provider | Provider enables nixpkgs' default font set; the reference host adds its own |
| `tuigreet --time` fixed in the greeter module | `sysMod.greeter.arguments`, set by the host |
| `moduleArgs = { inherit inputs; }` suggested, although `inputs` is reserved | Examples use a name of the config flake's choice |
| No check for the two points above | Checks added; see the mutation run in section 5 |

Raised and left open on purpose (recorded in the spec, section 15):

- Rollout: target address, build host, order of system and home, rollback.
- A user delivered standalone on an otherwise NixOS-managed host.
- Two providers for one capability.
- Per-deployment nixpkgs (and the matching system-manager release).
- Renaming and retiring hosts and users; secret rotation and key loss.
- macOS.

## 5. What was run

On the VM, with the committed lock files (`--no-update-lock-file`):

| Command | Result |
|---|---|
| `nix flake check --no-build --all-systems --option allow-import-from-derivation false` on the root flake | passes: `nixos-desktop`, `nixos-server`, 35 `framework-*` checks |
| the same on `framework/` | passes for `x86_64-linux` and `aarch64-linux` |
| `nix build` of `checks.x86_64-linux.nixos-desktop` and `nixos-server` | both systems build |
| `nix build` of a fixture system-manager config and two standalone closures (scratch flake using the framework flake module) | build |
| `hjem standalone switch` into a sandbox home, twice, then with a reduced user, then `rollback` | files linked, packages in a profile, a pre-existing file moved to `.backup-<name>`, stale links removed, rollback restores them |
| `agenix rekey` on the fixture, then `checks.x86_64-linux.fleet-secret-decrypts` | the rekeyed copy decrypts with the fixture host key |
| `fuzzel --check-config` on the generated `fuzzel.ini` | valid (the previous file was rejected) |
| Eight deliberate mutations of the framework (no files or packages to Hjem, optional wins over required, a `false` capability counts as provided, desktop offered on every host, disabled users still count, standalone drops packages, standalone users reconciled alone) | each one fails a named check |

Not run: no system was switched or booted; no real non-NixOS machine was
touched; agenix activation on a running host (owner and mode of
`/run/agenix/<name>`) was not observed.

## 6. What you still have to supply

- **Real hosts.** `desktop` and `server` are references for the one libvirt
  guest. `server` has no hardware report; generate one per real machine.
- **Keys.** A YubiKey identity stub and a backup recipient before
  `framework.secrets` can be switched on; each host's SSH public key as
  `hostKey`.
- **Logins.** Real hosts need `authorizedKeys` (and `hashedPasswordFile` from a
  secret) instead of the guest's password.
- **`hardware.facter.reportPath`.** Not enabled: nixpkgs would then also
  configure kernel modules and DHCP from the report. Decide per host.
- **Behaviour changes if you switch the guest to this commit:** the greeter
  runs as `greeter`; the `laptop` deployment is gone, `server` is new; fonts
  are nixpkgs' default set plus `noto-fonts` (larger than the previous four;
  `fonts.enableDefaultPackages = false` in the hostConf turns it off); fuzzel
  reads a valid config; fish sections are ordered settings, environment, yazi,
  zoxide, direnv.
