# Secrets fixture

Nothing here protects anything. The files exist so the checks can run the real
agenix-rekey artefacts through the secrets provider.

| File | What it is |
|---|---|
| `demo-token.age` | The text `fixture value, used by no host`, encrypted to a throwaway master key whose private half was deleted after rekeying. |
| `rekeyed/sec-1/*-demo-token.age` | Output of `agenix rekey` for the fixture host `sec-1`: the same text, encrypted to that host's key. |
| `fixture-host-key` | Private SSH host key of the fixture host. It is committed on purpose so a check can prove the rekeyed copy decrypts. Its public half is `hostKey` in `hosts/sec-1/facts.nix`. |

To regenerate (for example after changing the host key), in a scratch flake
that imports the framework flake module with `root` pointing at a copy of this
tree:

```sh
rage-keygen -o master.txt                       # throwaway master
ssh-keygen -t ed25519 -N "" -f fixture-host-key  # then update hosts/sec-1/facts.nix
printf 'fixture value, used by no host\n' | rage -e -r "$(rage-keygen -y master.txt)" -o secrets/demo-token.age
nix run .#agenix-rekey.x86_64-linux.rekey       # with framework.secrets.masterIdentities = [ ./master.txt ]
```

Then copy `demo-token.age`, `rekeyed/` and the key back, put the master's
public key into `secrets.extraEncryptionPubkeys` in `framework/checks/default.nix`,
and delete `master.txt`.
