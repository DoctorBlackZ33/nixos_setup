{ ... }:

{
  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = [ "--write-kubeconfig-mode=0600" ];

    # ServiceLB/Traefik publish host ports through Kubernetes NAT, bypassing
    # the host INPUT firewall. Ingress is an explicit deployment decision.
    disable = [ "traefik" "servicelb" ];
  };

  # Let pods reach the node API/kubelet without opening physical interfaces.
  networking.firewall.trustedInterfaces = [ "cni0" "flannel.1" ];

  # Flannel and the CNI, not NetworkManager, own these virtual interfaces.
  networking.networkmanager.unmanaged = [
    "interface-name:cni0"
    "interface-name:flannel.1"
  ];
}
