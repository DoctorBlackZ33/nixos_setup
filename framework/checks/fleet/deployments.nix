# Synthetic fleet: thirteen hosts mixing workstations and servers across the
# three ways a host can be managed. `valid` must evaluate end to end; every
# entry of `invalid` must be rejected, and the checks say with which message;
# `edge` entries must evaluate for a reason the checks spell out.
{
  valid = {
    # NixOS
    ws-1 = { users = [ "alice" "bob" ]; };
    ws-2 = { users = [ "alice" ]; };
    ws-3 = { };
    srv-1 = { };
    srv-2 = { users = [ "bob" "lena" ]; };
    srv-arm = { users = [ "alice" ]; };
    sec-1 = { users = [ "dave" ]; };

    # system-manager on a foreign distribution
    sm-ws = { users = [ "alice" ]; };
    sm-srv = { users = [ "bob" ]; };
    sm-arm = { };

    # unmanaged hosts: user layer only
    man-ws = { users = [ "alice" ]; };
    man-srv = {
      users = [ "bob" ];
      homes.bob = "/srv/home/bob";
    };
    man-arm = { users = [ "bob" ]; };
  };

  invalid = {
    # carol asks for a compositor wherever she lands; servers must refuse her,
    # and only her.
    nixos-server = {
      host = "srv-1";
      users = [ "carol" ];
    };
    system-manager-server = {
      host = "sm-srv";
      users = [ "bob" "carol" ];
    };
    manual-server = {
      host = "man-srv";
      users = [ "bob" "carol" ];
    };

    # gina and hugo want one secret with different modes.
    manual-conflict = {
      host = "man-srv";
      users = [ "gina" "hugo" ];
    };

    # erin has a user configuration but no account file.
    no-account = {
      host = "srv-1";
      users = [ "erin" ];
    };
    disabled-no-account = {
      host = "srv-no-account-off";
      users = [ "erin" ];
    };

    # Two users cannot both be the reader of one secret.
    shared-secret = {
      host = "sec-1";
      users = [ "dave" "dana" ];
    };

    # Hosts that contradict or rewrite their own facts.
    identity-mismatch = { host = "bad-name"; };
    facts-override = { host = "bad-facts"; };

    # A manual host cannot provide secrets.
    manual-secret = {
      host = "man-secret";
      users = [ "bob" ];
    };

    # Account files that overstep or are misspelled, on a host with a system
    # and on one without.
    account-groups = {
      host = "srv-1";
      users = [ "judy" ];
    };
    account-typo = {
      host = "srv-1";
      users = [ "kent" ];
    };
    account-typo-manual = {
      host = "man-srv";
      users = [ "kent" ];
    };

    # Known fields with wrong types must be forced on every delivery path.
    account-uid-nixos = { host = "srv-1"; users = [ "mira" ]; };
    account-uid-system-manager = { host = "sm-srv"; users = [ "mira" ]; };
    account-uid-manual = { host = "man-srv"; users = [ "mira" ]; };
    account-description-nixos = { host = "srv-1"; users = [ "nick" ]; };
    account-description-system-manager = { host = "sm-srv"; users = [ "nick" ]; };
    account-description-manual = { host = "man-srv"; users = [ "nick" ]; };
  };

  edge = {
    # carol is switched off in that host's configuration.
    disabled-user = {
      host = "srv-off";
      users = [ "carol" ];
    };
  };
}
