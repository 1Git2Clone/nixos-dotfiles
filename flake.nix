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

    # Just a config tree, symlinked into ~/.config/nvim by home/hutao.nix.
    nvim-config = {
      url = "github:1Git2Clone/nvim-config";
      flake = false;
    };

    # The user layer. home/hutao.nix links it into $HOME instead of stowing it.
    dotfiles = {
      url = "git+https://git.hu-tao.dev/hutao/dotfiles";
      flake = false;
    };
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
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Shared by the laptop and the VM. Anything in here is genuinely
      # exercised by `nix run .#vm`; anything outside it is not.
      desktopModules = [
        # Do NOT also import homeModules.stylix — it double-imports.
        stylix.nixosModules.stylix

        home-manager.nixosModules.home-manager

        ./modules/system.nix
        ./modules/desktop.nix
        ./modules/neovim.nix

        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "hm-bak";
            extraSpecialArgs = { inherit inputs; };
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

            # Generic; a model-specific ideapad profile may also exist.
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

        vm = self.nixosConfigurations.hutao-vm.config.system.build.vm;

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

      formatter.${system} = pkgs.nixfmt;
    };
}
