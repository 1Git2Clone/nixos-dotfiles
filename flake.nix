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

    # The an-anime-team launchers. Its own binary cache is the point --
    # see modules/desktop/aagl.nix.
    aagl = {
      url = "github:ezKEa/aagl-gtk-on-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Sober is Flatpak-only by upstream's choice, and this keeps that
    # declarative rather than a `flatpak install` nobody records.
    nix-flatpak.url = "github:gmodena/nix-flatpak";

    # The code-graph MCP server opencode and claude-code both call. Upstream
    # ships a flake, so this is their package rather than a build of ours --
    # pinned to a tag, because the config names a binary this has to provide.
    codebase-memory-mcp = {
      url = "github:DeusData/codebase-memory-mcp/v0.11.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Worktree + tmux window per agent. Upstream's own flake, pinned to a tag:
    # it releases several times a day, and a moving ref would rebuild the
    # binary on every `nix flake update`.
    workmux = {
      url = "github:raine/workmux/v0.1.264";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The new tab and site themes that follow the caelestia scheme, and Zen's
    # live colours (lib.wrapZen). Locked to a revision of main:
    # `nix flake update caelestia-tab` to pick up a push. A rebuild with
    # --override-input doesn't write the lock, so a machine rebuilt only
    # that way leaves every other one on the old revision.
    caelestia-tab = {
      url = "git+https://git.hu-tao.dev/hutao/caelestia-tab?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Zen isn't in nixpkgs. Its packages are wrapFirefox builds, so they take
    # nativeMessagingHosts the same way floorp-bin does.
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Local toolbox of language-agnostic CLI utilities. Forgejo is the source of
    # truth and GitHub is a push-only mirror; both hosts are credentialed by the
    # netrc that modules/sops.nix renders, so either URL works.
    #
    # Nix flake inputs do not fail over, so this is the primary and the mirror is
    # the escape hatch -- one flag, no edit, no dirty tree:
    #
    #   sudo nixos-rebuild switch --flake ~/Projects/nixos-dotfiles#hutao-desktop \
    #     --override-input cli-utils git+https://github.com/1Git2Clone/cli-utils?ref=main
    #
    # It is a git input now, not `path:`, so it is locked to a revision: a push
    # needs `nix flake update cli-utils` before a rebuild sees it.
    cli-utils = {
      url = "git+https://git.hu-tao.dev/hutao/cli-utils?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The Neovim config and the home-manager module that installs it, with
    # Forgejo as the source and GitHub as a mirror, failed over to like
    # cli-utils:
    #
    #   --override-input nvim-config git+https://github.com/1Git2Clone/nvim-config?ref=main
    #
    # Locked to a revision: a push there needs `nix flake update nvim-config`.
    nvim-config.url = "git+https://git.hu-tao.dev/hutao/nvim-config?ref=main";

    # Artwork that is not ours to publish, so it lives in its own private repo:
    # a clone of THIS repo must not carry it, and neither must any copy of it.
    # Per-pack terms are in that repo's README.
    #
    # `flake = false` because it is a tree of packs rather than a flake -- one
    # directory per theme under assets/third-party/, which is the shape
    # pkgs/cursors.nix reads after appending that segment.
    #
    # Locked to a revision like cli-utils, so a push to that repo needs
    # `nix flake update third-party-assets` before a rebuild sees it.
    third-party-assets = {
      url = "git+https://git.hu-tao.dev/hutao/nixos-dotfiles-third-party-assets?ref=main";
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
      deploy-rs,
      third-party-assets,
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
            # ./home imports every file in home/apps -- the editor toolchain
            # is a user profile, not a system one.
            users.hutao = import ./home;
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

        # Ryzen 5 3600X, RX 5600 XT, 16GB, NVMe + a LUKS ext4 HDD it only mounts.
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

      # Every cursor theme, by its directory name, so `nix build
      # .#cursors.KAngel-Cursor` works and a new pointer needs no edit here.
      # The packs come from third-party-assets; assets/ is scanned too, for a
      # theme that is ours to publish.
      #
      # legacyPackages rather than packages, and nested rather than merged in
      # with //, for the same reason: `//` forces both operands, so ANY lookup
      # in packages.${system} -- `nix develop .#ci` probing it for a shell, to
      # name the one that bit -- fetched the private assets repo just to learn
      # the attribute names. That made a lint job that never touches a cursor
      # need a credential to run. Under a lazy attribute nothing is fetched
      # until someone actually asks for a theme, and legacyPackages is where a
      # nested set belongs: `packages` must be derivations all the way down.
      legacyPackages.${system}.cursors = pkgs.callPackage ./pkgs/cursors.nix {
        thirdParty = third-party-assets;
      };

      packages.${system} = {
        installer-iso = self.nixosConfigurations.installer.config.system.build.isoImage;

        inherit (self.nixosConfigurations.hutao-vm.config.system.build) vm;

        # The CLI that formats the disk, pinned to the same input as the
        # module that describes the layout. install.sh runs this rather than
        # `github:nix-community/disko/latest`, which is a moving ref and can
        # partition with a different version than the config was written for.
        inherit (disko.packages.${system}) disko;

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

        # The handbook, live-reloading. mdbook-mermaid install writes the two
        # gitignored JS files docs/book.toml references; without them the
        # build fails naming a file nobody wrote.
        docs = {
          type = "app";
          program = "${
            pkgs.writeShellApplication {
              name = "serve-docs";
              runtimeInputs = with pkgs; [
                mdbook
                mdbook-mermaid
              ];
              text = ''
                mdbook-mermaid install docs
                exec mdbook serve docs "$@"
              '';
            }
          }/bin/serve-docs";
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

            # The handbook in docs/; see docs/book.toml.
            mdbook
            mdbook-mermaid
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
            # For the mdbook pre-commit hook and .forgejo/workflows/pages.yml.
            mdbook
            mdbook-mermaid
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
