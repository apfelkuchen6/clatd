{
  description = "jool clat configuration thing";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {self, nixpkgs, flake-utils, ...}@inputs:
    flake-utils.lib.eachSystem (with flake-utils.lib.system; [ x86_64-linux aarch64-linux ])
      (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in rec {
        packages.clatd = with pkgs;
          stdenvNoCC.mkDerivation {
            name = "clatd";

            src = inputs.self;

            nativeBuildInputs = [ makeWrapper ];
            buildInputs = with perlPackages; [
              perl
              (NetDNS.overrideAttrs
                (_: { patches = [ ./net-dns-fix-local-resolver.patch ]; }))
              NetIP
            ];

            makeFlags = [ "PREFIX=$(out)" ];

            preBuild = ''
              mkdir -p $out/sbin
            '';

            postFixup = ''
              wrapProgram $out/bin/clatd \
                --prefix PERL5LIB : $PERL5LIB \
                --prefix PATH : ${lib.makeBinPath [ kmod jool-cli iproute2 ]}
            '';
          };
        packages.default = packages.clatd;
        checks.jool-xlat464 =
          import ./tests/jool-xlat464.nix { inherit pkgs self; };
        devShells.default = pkgs.mkShell {
          inputsFrom = [ packages.clatd ];
          nativeBuildInputs = [ pkgs.jool-cli ];
        };
      }) // {
        nixosModules.jool-clat = import ./nixos-modules/jool-clat.nix self;
        nixosModules.jool-nat64 = import ./nixos-modules/jool-nat64.nix;
      };
}
