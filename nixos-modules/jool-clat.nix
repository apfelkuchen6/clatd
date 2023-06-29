self: { config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.jool-clat;
  configFile = pkgs.writeText "config" (lib.concatStringsSep "\n"
    (lib.mapAttrsToList (key: value: "${key}=${toString value}") cfg.settings));
in {
  options = {
    services.jool-clat = {
      enable = mkEnableOption (lib.mdDoc "jool-clat");

      package = mkOption {
        type = types.package;
        default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
        description =
          lib.mdDoc "This option specifies the jool-clat package to use.";
      };

      networkd-integration = mkEnableOption
        (lib.mdDoc "networkd integration via networkd-dispatcher");

      networkmanager-integration =
        mkEnableOption (lib.mdDoc "network-manager integration");

      settings = mkOption {
        type = with types; attrsOf (oneOf [ str int bool ]);
        description = lib.mdDoc ''
          This option specifies the jool-clat configuration.
          See <https://github.com/apfelkuchen6/jool-clat/blob/main/README.pod>
          for available options.
        '';
        example = literalExpression ''
          { plat-prefix = '2001:db8:6464::/96'; }
        '';
        default = { };
      };
    };
  };

  config = mkIf cfg.enable {

    boot.extraModulePackages = with config.boot.kernelPackages; [ jool ];

    networking.networkmanager.dispatcherScripts =
      lib.mkIf cfg.networkmanager-integration [{
        source = pkgs.writeText "clat" ''
          [ "$DEVICE_IFACE" == ${cfg.settings.clat-dev or "clat"} ] || ${cfg.package}/bin/clatd -c ${configFile}
        '';
        type = "basic";
      }];

    services.networkd-dispatcher = lib.mkIf cfg.networkd-integration {
      enable = true;
      rules.clat = {
        onState = [ "routable" "dormant" "no-carrier" "off" "carrier" "degraded" "configuring" "configured" ];
        script = ''
          #!${pkgs.runtimeShell}
          [ "$IFACE" == ${cfg.settings.clat-dev or "clat"} ] || ${cfg.package}/bin/clatd -c ${configFile}
        '';
      };
    };

    systemd.services.jool-clat =
      # if these are used, using the systemd service additionaly doesn't make any sense
      lib.mkIf (!(cfg.networkd-integration || cfg.networkmanager-integration)) {
      description = "Stateless jool siit ";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${cfg.package}/bin/clatd -c ${configFile}";
        ExecReload = "${cfg.package}/bin/clatd -c ${configFile}";

        CapabilityBoundingSet = [
          "CAP_NET_ADMIN" # network configuration
          "CAP_SYS_MODULE" # loading the jool kernel module
          "CAP_SYS_ADMIN" # namespace stuff
        ];
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_NETLINK" ];
        MemoryDenyWriteExecute = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        ProtectHostname = true;
      };
    };
  };
}
