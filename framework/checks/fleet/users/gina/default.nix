# Would like a secret, readable by herself only. hugo wants the same secret
# with another mode.
{ ... }:
{
  requires.secrets.shared = {
    required = false;
    mode = "0400";
  };
}
