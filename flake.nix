{
  description = "jool clat configuration thing";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs:
    inputs.flake-utils.lib.eachDefaultSystem (system:
      let pkgs = inputs.nixpkgs.legacyPackages.${system};
      in rec {
        packages.clatd = with pkgs; stdenvNoCC.mkDerivation {
          name = "clatd";
          makeFlags = [ "PREFIX=$(out)" ];
          preBuild = ''
            mkdir -p $out/sbin
          '';
          nativeBuildInputs = [ makeWrapper ];
          buildInputs = with perlPackages; [ perl NetDNS NetIP ];
          src = inputs.self;
          postFixup = ''
            wrapProgram $out/bin/clatd --prefix PERL5LIB : $PERL5LIB
          '';
        };
        packages.default = packages.clatd;
      });
}
