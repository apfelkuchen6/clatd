(import ./lib.nix) {
  name = "jool-xlat464";
  nodes = {
    clat = { self, config, lib, pkgs, ... }: {
      # imports = [ self.nixosModules.default ];
      virtualisation.vlans = [ 1 ];
      networking = {
        useNetworkd = true;
        useDHCP = false;
      };
      services.resolved.dnssec = "false";
      systemd.network.networks."01-lan" = {
        name = "eth1";
        address = [ "2001:db8::1/64" ];
        routes = [{
          routeConfig = {
            Gateway = "2001:db8::64";
            Destination = "64:ff9b::/96";
          };
        }];
        networkConfig = {
          DNS = "2001:db8::64";
          DNSSEC = false;
        };
      };
      environment.systemPackages = [ pkgs.dig self.packages.${pkgs.stdenv.hostPlatform.system}.clatd ];
      boot.extraModulePackages = with config.boot.kernelPackages; [ jool ];
    };

    plat = { config, pkgs, ... }: {
      virtualisation.vlans = [ 1 2 ];
      networking = {
        useNetworkd = true;
        useDHCP = false;
        firewall.enable = false;
      };
      systemd.network.networks = {
        "01-eth1" = {
          name = "eth1";
          address = [ "2001:db8::64/64" ];
        };
        "02-legacynet" = {
          name = "eth2";
          address = [ "172.16.0.64/24" ];
        };
      };
      boot.extraModulePackages = with config.boot.kernelPackages; [ jool ];
      systemd.services.jool = {
        serviceConfig = {
          ExecStartPre = "${pkgs.kmod}/bin/modprobe jool";
          ExecStart =
            "${pkgs.jool-cli}/bin/jool instance add default --netfilter --pool6 64:ff9b::/96";
          ExecStop = "${pkgs.jool-cli}/bin/jool instance remove default";
          Type = "oneshot";
          RemainAfterExit = true;
        };
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
      };
      services.unbound = {
        enable = true;
        settings = {
          server = {
            access-control = [ "::/0 allow" ];
            interface = [ "2001:db8::64" ];
          };
          local-data = [
            ''"ipv4only.arpa. IN A 192.0.0.170"''
            ''"ipv4only.arpa. IN A 192.0.0.171"''
            ''"ipv4only.arpa. IN AAAA 64:ff9b::c000:aa"''
            ''"ipv4only.arpa. IN AAAA 64:ff9b::c000:ab"''
          ];
        };
      };
    };

    legacy = {
      virtualisation.vlans = [ 2 ];
      networking = {
        useNetworkd = true;
        useDHCP = false;
      };
      systemd.network.networks."02-legacynet" = {
        name = "eth1";
        address = [ "172.16.0.2/24" ];
      };
    };
  };
  testScript = ''
    legacy.start()
    plat.start()
    plat.wait_for_unit("systemd-networkd-wait-online.service")
    legacy.wait_for_unit("systemd-networkd-wait-online.service")
    plat.wait_for_unit("jool.service");
    plat.wait_for_unit("unbound.service");

    # test network connectivity to legacy
    plat.succeed("ping -c 1 172.16.0.2")

    clat.start()
    clat.wait_for_unit("systemd-networkd-wait-online.service")
    # test whether clat can reach legacy over nat64
    clat.succeed("ping -c 1 64:ff9b::172.16.0.2")

    # test whether clat can reach legacy over xlat464
    print(clat.succeed("sudo clatd -d -d"))
    clat.succeed("ping -c 1 172.16.0.2")
  '';
}
