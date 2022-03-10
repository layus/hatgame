{
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
        gomod2nix.url = "github:tweag/gomod2nix";
        gomod2nix.inputs.nixpkgs.follows = "nixpkgs";
    };
    outputs = { self, nixpkgs, gomod2nix }: {
        packages.x86_64-linux =
            let
                pkgs = nixpkgs.legacyPackages.x86_64-linux.extend gomod2nix.overlay;
            in
            {
                backend = pkgs.buildGoApplication {
                    pname = "hatgame-backend";
                    version = "0.1";
                    src = ./hatgame-backend;
                    modules = ./hatgame-backend/gomod2nix.toml;
                };
            };
    };
}
