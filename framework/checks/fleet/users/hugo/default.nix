# Wants the secret gina asks for, but group-readable.
{ ... }:
{
  requires.secrets.shared = {
    required = false;
    mode = "0440";
  };
}
