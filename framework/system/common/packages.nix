# Administration tools every managed host gets, servers included.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    curl
    git
    jq
    rsync
  ];
}
