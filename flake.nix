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
            buildInputs = with perlPackages; [ perl NetDNS NetIP ];

            makeFlags = [ "PREFIX=$(out)" ];

            preBuild = ''
              mkdir -p $out/sbin
            '';

            postFixup = ''
              wrapProgram $out/bin/clatd \
                --prefix PERL5LIB : $PERL5LIB \
                --prefix PATH : ${lib.makeBinPath [ sysctl jool-cli iproute2 ]}
            '';
          };
        packages.default = packages.clatd;
        checks.jool-xlat464 =
          import ./tests/jool-xlat464.nix { inherit pkgs self; };
        devShells.default = pkgs.mkShell {
          inputsFrom = [ packages.clatd ];
        };
      }) // {
        nixosModules.default = ./nixos-module.nix;
      };
}
