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

    # Not a flake — just a config tree we symlink into ~/.config/nvim. Pinned
    # here rather than stowed, so `nix flake update` is what moves it and a
    # fresh install needs no extra clone. See home/hutao.nix for the tradeoff.
    nvim-config = {
      url = "github:1Git2Clone/nvim-config";
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

      # The desktop layer, shared by the laptop and the test VM. If it is in
      # here, booting the VM genuinely exercises it; if it is not, the VM
      # proves nothing about it.
      #
      # hosts/common — bootloader, users, secrets — is deliberately absent:
      # all of it needs real firmware or a real install. hosts/hutao-laptop
      # imports it; hosts/vm does not.
      desktopModules = [
        # Stylix's NixOS module automatically sets up its home-manager module
        # when it detects home-manager running as a NixOS module. Do NOT also
        # import homeModules.stylix — that double-imports.
        stylix.nixosModules.stylix

        home-manager.nixosModules.home-manager

        ./modules/system.nix
        ./modules/desktop.nix

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

            # Generic profiles — safe and always present. A model-specific
            # ideapad profile may also exist; check with
            #   nix flake show github:NixOS/nixos-hardware | grep -i ideapad
            nixos-hardware.nixosModules.common-cpu-amd
            nixos-hardware.nixosModules.common-gpu-amd
            nixos-hardware.nixosModules.common-pc-laptop
            nixos-hardware.nixosModules.common-pc-laptop-ssd

            ./hosts/hutao-laptop
          ];
        };

        # Same desktop, under QEMU, no install required.  nix run .#vm
        hutao-vm = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = desktopModules ++ [ ./hosts/vm ];
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

        # Build-only check: does the laptop's real closure exist? The cheapest
        # way to catch a renamed package. Needs hardware-configuration.nix and
        # the encrypted hashes, so it only works post-install.
        laptop = self.nixosConfigurations.hutao-laptop.config.system.build.toplevel;

        default = self.packages.${system}.installer-iso;
      };

      apps.${system} = {
        # Boot the desktop VM.
        vm = {
          type = "app";
          program = "${self.packages.${system}.vm}/bin/run-hutao-vm-vm";
        };

        # Full install rehearsal: boots the installer ISO in QEMU against a
        # blank virtual NVMe and runs install.sh end to end.
        install-test = {
          type = "app";
          program = "${
            pkgs.writeShellApplication {
              name = "install-test";
              # OVMF is found at runtime, not pinned here: the script has to
              # work on the Arch host too, where the firmware comes from the
              # distro rather than the store.
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
            # secrets
            sops
            age
            ssh-to-age
            mkpasswd

            # nix tooling
            nixd
            # nixfmt, not nixpkgs-fmt: every .nix file here is formatted with
            # it and the two disagree on multi-argument lambdas, so the wrong
            # one reformats the whole tree on first use.
            nixfmt-rfc-style
            statix
            deadnix

            # the VM harness
            qemu
            socat

            # hooks — `pre-commit install` once per clone, after which
            # .pre-commit-config.yaml is enforced on every commit. CI runs the
            # same file, so the two cannot drift.
            pre-commit
            gitleaks
            shellcheck
            shfmt
            markdownlint-cli
          ];
        };

        # What CI enters. Deliberately NOT the full dev shell: that one pulls
        # nixd, qemu and nixos tooling, none of which a lint check needs and
        # all of which CI would download every run.
        ci = pkgs.mkShell {
          packages = with pkgs; [
            pre-commit
            nixfmt-rfc-style
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

      formatter.${system} = pkgs.nixfmt-rfc-style;
    };
}
