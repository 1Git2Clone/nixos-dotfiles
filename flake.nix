{
  description = "hutao's NixOS system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware";

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Imported by home/hutao.nix: the NixOS module would put per-user state in
    # /var/lib and export HERMES_HOME system-wide.
    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Sober is Flatpak-only by upstream's choice, and this keeps that
    # declarative rather than a `flatpak install` nobody records.
    nix-flatpak.url = "github:gmodena/nix-flatpak";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      disko,
      sops-nix,
      nixos-hardware,
      stylix,
      home-manager,
      deploy-rs,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # The crate's source fetch 403s on the pinned revision, and the lib
      # embeds that binary in the closure. Upstream's documented workaround:
      # lib from the flake, binary from nixpkgs.
      deployPkgs = import nixpkgs {
        inherit system;
        overlays = [
          deploy-rs.overlays.default
          (_: super: {
            deploy-rs = {
              inherit (pkgs) deploy-rs;
              inherit (super.deploy-rs) lib;
            };
          })
        ];
      };

      # Everything in here is exercised by `nix run .#vm`; nothing else is.
      desktopModules = [
        # Do NOT also import homeModules.stylix — it double-imports.
        stylix.nixosModules.stylix

        home-manager.nixosModules.home-manager

        ./modules/system.nix
        ./modules/desktop

        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "hm-bak";
            extraSpecialArgs = { inherit inputs; };
            # Which also imports modules/neovim.nix -- the editor toolchain
            # is a user profile, not a system one.
            users.hutao = import ./home/hutao.nix;
          };
        }
      ];
    in
    {
      nixosConfigurations = {
        # The real machine.
        hutao-laptop = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = desktopModules ++ [
            disko.nixosModules.disko
            sops-nix.nixosModules.sops

            nixos-hardware.nixosModules.common-cpu-amd
            nixos-hardware.nixosModules.common-gpu-amd
            nixos-hardware.nixosModules.common-pc-laptop
            nixos-hardware.nixosModules.common-pc-laptop-ssd

            ./hosts/hutao-laptop
          ];
        };

        # Ryzen 5 3600X, RX 5700 XT, 16GB, NVMe + an NTFS HDD it only mounts.
        hutao-desktop = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = desktopModules ++ [
            disko.nixosModules.disko
            sops-nix.nixosModules.sops

            nixos-hardware.nixosModules.common-cpu-amd
            nixos-hardware.nixosModules.common-gpu-amd
            nixos-hardware.nixosModules.common-pc-ssd

            ./hosts/hutao-desktop
          ];
        };

        # Same desktop, under QEMU, no install required.  nix run .#vm
        hutao-vm = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = desktopModules ++ [ ./hosts/hutao-vm ];
        };

        # The installer image the rehearsal boots.  nix build .#installer-iso
        installer = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ ./hosts/installer ];
        };
      };

      packages.${system} = {
        installer-iso = self.nixosConfigurations.installer.config.system.build.isoImage;

        inherit (self.nixosConfigurations.hutao-vm.config.system.build) vm;

        # The CLI that formats the disk, pinned to the same input as the
        # module that describes the layout. install.sh runs this rather than
        # `github:nix-community/disko/latest`, which is a moving ref and can
        # partition with a different version than the config was written for.
        inherit (disko.packages.${system}) disko;

        hutao-cursor = pkgs.callPackage ./pkgs/hutao-cursor.nix { };

        sddm-hu-tao = pkgs.callPackage ./pkgs/sddm-hu-tao.nix { };

        laptop = self.nixosConfigurations.hutao-laptop.config.system.build.toplevel;
        desktop = self.nixosConfigurations.hutao-desktop.config.system.build.toplevel;

        default = self.packages.${system}.installer-iso;
      };

      apps.${system} = {
        # Boot the desktop VM.
        vm = {
          type = "app";
          program = "${self.packages.${system}.vm}/bin/run-hutao-vm-vm";
        };

        install-test = {
          type = "app";
          program = "${
            pkgs.writeShellApplication {
              name = "install-test";
              # OVMF found at runtime, so this works on non-NixOS hosts.
              runtimeInputs = with pkgs; [
                qemu
                socat
                openssh
                rsync
                imagemagick
              ];
              text = builtins.readFile ./vm/install-test.sh;
            }
          }/bin/install-test";
        };
      };

      devShells.${system} = {
        default = pkgs.mkShell {
          packages = with pkgs; [
            sops
            age
            ssh-to-age
            mkpasswd

            nixd
            nixfmt
            statix
            deadnix

            qemu
            socat

            # Qualified: a bare `deploy-rs` resolves to the flake input, which
            # shadows `with pkgs`.
            pkgs.deploy-rs

            # `pre-commit install` once per clone; CI runs the same file.
            pre-commit
            gitleaks
            shellcheck
            shfmt
            markdownlint-cli
          ];
        };

        # What CI enters — no nixd/qemu, which a lint check does not need.
        ci = pkgs.mkShell {
          packages = with pkgs; [
            pre-commit
            nixfmt
            statix
            deadnix
            git
            gitleaks
            shellcheck
            shfmt
            markdownlint-cli
          ];
        };
      };

      # Remote deploys over Tailscale SSH. sshUser = "root" on purpose: the
      # tailnet ACL is the credential, so security.sudo.wheelNeedsPassword stays
      # true and access is revocable from the admin console rather than from the
      # machine.
      #
      # magicRollback makes the target confirm itself over the tailnet after
      # activating and roll back if it cannot — the failure mode that matters
      # when the link you deploy over is the one you might break.
      deploy.nodes.hutao-laptop = {
        hostname = "hutao-laptop"; # MagicDNS, so no address is pinned here
        sshUser = "root";
        # Tailscale SSH authenticates the peer by node key over WireGuard and
        # presents its own host key, which is not in known_hosts. accept-new
        # rather than no, so a later change is still caught.
        sshOpts = [
          "-o"
          "StrictHostKeyChecking=accept-new"
        ];
        magicRollback = true;
        autoRollback = true;
        profiles.system = {
          user = "root";
          path = deployPkgs.deploy-rs.lib.activate.nixos self.nixosConfigurations.hutao-laptop;
        };
      };

      checks.${system} = deployPkgs.deploy-rs.lib.deployChecks self.deploy;

      formatter.${system} = pkgs.nixfmt;
    };
}
