{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    gomod2nix.url = "github:tweag/gomod2nix";
    gomod2nix.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { self, nixpkgs, gomod2nix }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux.extend gomod2nix.overlay;
    in
    {
      packages.x86_64-linux =
        {
          backend = pkgs.buildGoApplication {
            pname = "hatgame-backend";
            version = "0.1";
            src = ./hatgame-backend;
            modules = ./hatgame-backend/gomod2nix.toml;
            meta.mainProgram = "hatgame";
            shellHook = ''
              cd hatgame-backend && eval "$configurePhase"
            '';
          };
        };
      defaultPackage.x86_64-linux = self.packages.x86_64-linux.backend;
      devShell.x86_64-linux = self.packages.x86_64-linux.backend;
      nixosModule = { pkgs, config, lib, ... }:
        let
          cfg = config.services.hatgame;
          dbusername = "hatgame";
          dbname = "hatgamedb";
          dbpassword = "asdf";
          workdir =
            let psqlinfo =
              {
                host = "127.0.0.1";
                port = config.services.postgresql.port;
                user = dbusername;
                dbname = dbname;
                password = dbpassword;
                sslmode = "disable";
              };
            in
            pkgs.writeTextDir "psqlInfo.json" (builtins.toJSON psqlinfo);
        in
        {
          options.services.hatgame = {
            enable = lib.mkEnableOption "hatgame";
          };
          config = lib.mkIf cfg.enable {
            services.postgresql = {
              enable = true;
              ensureDatabases = [ dbname ];
              initialScript = pkgs.writeText "init" ''
                create role ${dbusername} with login password '${dbpassword}' createdb;
              '';
              ensureUsers = [{
                name = dbusername;
                ensurePermissions = {
                  "DATABASE ${dbname}" = "ALL PRIVILEGES";
                };
              }];
              authentication = ''
                host all all 0.0.0.0/0 md5
                host all all ::/0 md5
              '';
            };
            systemd.services.hatgame = {
              description = "hatgame backend";
              script =
                "${self.packages.x86_64-linux.backend}/bin/hatgame";
              wantedBy = [ "multi-user.target" ];
              requires = [ "postgresql" ];
              after = [ "postgresql" ];
              serviceConfig = {
                WorkingDirectory = "${workdir}";
                Restart = "always";
              };
            };
          };
        };
      nixosConfigurations.hatgame = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ({ modulesPath, ... }:
            {
              imports = [ self.nixosModule ];
              boot.isContainer = true;
              networking.hostName = "hatgame";
              services.hatgame.enable = true;
            }
          )
        ];
      };
    };
}
