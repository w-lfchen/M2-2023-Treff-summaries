{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rubos-tuda-template = {
      url = "github:Rdeisenroth/Rubos-TUDA-Template";
      flake = false;
    };
    tuda-logo = {
      url = "https://upload.wikimedia.org/wikipedia/de/2/24/TU_Darmstadt_Logo.svg";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      pre-commit-hooks,
      rubos-tuda-template,
      tuda-logo,
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      packages.${system} = {
        rubos-tuda-template = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
          pname = "rubos-tuda-template";
          version = "0.1.0";
          src = rubos-tuda-template;
          passthru = {
            pkgs = [ finalAttrs.finalPackage ];
            tlDeps = with pkgs.texlive; [ latex ];
            tlType = "run";
          };
          buildInputs = with pkgs; [ librsvg ];
          installPhase = ''
            mkdir -p $out/tex/latex/rubos-template
            cp -t $out/tex/latex/rubos-template/ $src/tex/*

            mkdir -p $out/tex/latex/local
            rsvg-convert -f pdf -o $out/tex/latex/local/tuda_logo.pdf ${tuda-logo}
          '';
        });
        texliveFull-patched = pkgs.texlive.combine {
          inherit (pkgs.texlive) scheme-full;
          inherit (self.packages.${system}) rubos-tuda-template;
        };
      };

      devShells.${system}.default = pkgs.mkShell {
        inherit (self.checks.${system}.pre-commit-check) shellHook;
        buildInputs = self.checks.${system}.pre-commit-check.enabledPackages;
        packages = with pkgs; [
          python311Packages.pygments
          self.packages.${system}.texliveFull-patched
        ];
      };

      checks.${system}.pre-commit-check = pre-commit-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          end-of-file-fixer.enable = true;
          latexindent = {
            enable = true;
            settings.flags = "--overwriteIfDifferent --silent -l=latexindent.yaml";
          };
          trim-trailing-whitespace.enable = true;
        };
      };

      formatter.${system} = pkgs.nixfmt-rfc-style;
    };
}
