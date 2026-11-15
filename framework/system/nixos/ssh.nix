{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.sysMod.ssh;

  hasKey = user:
    user.openssh.authorizedKeys.keys != [ ] || user.openssh.authorizedKeys.keyFiles != [ ];
in
{
  options.sysMod.ssh = {
    enable = mkOption {
      type = types.bool;
      default = config.contract.facts.kind == "server";
      defaultText = lib.literalExpression "true on servers";
      description = "Run the OpenSSH server.";
    };
    passwordAuthentication = mkOption {
      type = types.bool;
      default = false;
      description = "Allow password logins. Keys are the default.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = cfg.passwordAuthentication;
        KbdInteractiveAuthentication = false;
      };
    };

    assertions = [
      {
        assertion = cfg.passwordAuthentication || lib.any hasKey (lib.attrValues config.users.users);
        message = ''
          host '${config.contract.facts.name}': sshd allows keys only but no account has an
          authorized key. Add `sysMod.accounts.<name>.authorizedKeys` or set
          `sysMod.ssh.passwordAuthentication = true`.
        '';
      }
    ];
  };
}
