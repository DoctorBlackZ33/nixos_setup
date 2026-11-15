# Needs one secret and writes its runtime path, never its value, into a file.
{ config, ... }:
{
  requires.secrets.demo-token = { };

  files.".config/demo/env".text = "TOKEN_FILE=${config.secretPath "demo-token"}";
}
