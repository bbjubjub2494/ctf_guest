# The flake file is the entry point for nix commands
{
  description = "idiosyncratic wrapper around RedNixOS";

  # Inputs are how Nix can use code from outside the flake during evaluation.
  inputs.devshell.url = "github:numtide/devshell";
  inputs.fup.url = "github:gytis-ivaskevicius/flake-utils-plus/v1.3.1";
  inputs.flake-compat.url = "github:edolstra/flake-compat";
  inputs.flake-compat.flake = false;
  inputs.miniguest.url = "github:lourkeur/miniguest";
  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";
  inputs.nixpkgs-21_11.url = "nixpkgs/nixos-21.11";

  inputs.distro.url = "github:lourkeur/distro";
  inputs.ate.url = "github:andir/ate";
  inputs.ate.flake = false;
  inputs.RedNixOS.url = "github:redcode-labs/RedNixOS";
  inputs.rednix.follows = "RedNixOS/rednix";

  # Outputs are the public-facing interface to the flake.
  outputs = inputs @ {
    self,
    devshell,
    distro,
    fup,
    miniguest,
    nixpkgs,
    RedNixOS,
    ...
  }:
    fup.lib.mkFlake {
      inherit self inputs;

      sharedOverlays = [
        devshell.overlay
        distro.overlays.packages
      ];

      hosts.RedNixOS = {
        system = "x86_64-linux";
        specialArgs = {
          # FIXME: compat hacks
          inputs = inputs.distro.inputs // {self = inputs.distro;};
          self = inputs.distro;
        };
        modules =
          distro.suites.base
          ++ distro.suites.dwm
          ++ [
            distro.profiles.hardware.persistence
            miniguest.nixosModules.core
            ({
                lib,
                pkgs,
                ...
              }: {
                nixpkgs.config.allowUnfree = true;
                nixpkgs.config.permittedInsecurePackages = [
                  "tightvnc-1.3.10"
                ];
                home-manager.useUserPackages = true;

                environment.persistence."/persist".directories = ["/home/red"];
                services.xserver.displayManager.autoLogin.user = "red";

                home-manager.users.red = {
                  imports = with distro.home.suites; base ++ dwm;
                  nixpkgs.overlays = [
                    (final: _: {
                      ate = final.callPackage inputs.ate {};
                    })
                  ];

                  services.syncthing.enable = true;

                  programs.dwm.colors = let
                    coal = "#100c0a";
                    ruby = "#e31e26";
                    lightgray = "#fce8c3";
                    white = "#FFFFFF";
                  in {
                    normfg = lightgray;
                    normbg = coal;
                    normborder = coal;
                    selfg = white;
                    selbg = ruby;
                    selborder = ruby;
                  };

                  lib.ate.config.options.BACKGROUND_COLOR = "#100c0a";

                  lib.background.bgfile = "${RedNixOS}/assets/RedNixOSWallpaperAscii.png";
                  home.stateVersion = "22.05";
                };

                _module.args = {
                  inherit inputs self;
                  pkgs21_11 = import inputs.nixpkgs-21_11 {
                    system = "x86_64-linux";
                    config.allowUnfree = true;
                  };
                };
                boot.miniguest.enable = true;
                boot.initrd.availableKernelModules = ["virtio_blk" "virtiofs"];

                fileSystems."/" = {
                  device = "root";
                  fsType = "tmpfs";
                  options = ["defaults" "mode=755"];
                };

                fileSystems."/persist" = {
                  device = "/dev/vda";
                  fsType = "ext4";
                  autoFormat = true;
                  autoResize = true;
                };

                fileSystems."/nix/store".fsType = lib.mkForce "virtiofs";

                environment.systemPackages =
                  [
                    (pkgs.python3.withPackages (p:
                      with p; [
                        pwntools
                        pycryptodome
                        gmpy2
                      ]))
                  ]
                  ++ pkgs.lib.attrValues inputs.rednix.packages.${pkgs.system};

                # conflict between RedNix and config
                nix.package = lib.mkForce pkgs.nixFlakes;
                time.timeZone = lib.mkForce "Europe/Zurich";
                services.xserver.layout = lib.mkForce "custom";
                i18n.defaultLocale = lib.mkForce "en_GB.UTF-8";

                users.users.red.openssh.authorizedKeys.keys = [
                  "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCNjyVyANhlBmXytKjbXmk+qe+Tb8KoAGAnqjhooE5I4pBZqdEvcWqw+vhi1zUpNFk1EA6c7/czV4rmYgfXzqOVTPcmOPbrnZoAa9et6oOJMYE2RsPMLGCM18kcZHU656xtS+HfrsX+VRnEu/n8Mxx1tOKPe+JM3m1gIan3WEhbaEOlivUeXY3arnjPx1f11WIiZ+ZymBuOYo0yvYAx6FpILcFvdMfWDsiNBWNaOKqMxe12vZ+3JmbEJWioPp+oD6gb6HF4x92jajuG/MwtGkwfaKbOeaUYDSaYezl2vabLSuDhvRzXxhvWmiBjGkEDG4Sf4eRAwZ8XVsI6t9P6sxrL cardno:000500003C7C
"
                ];
              })
            "${RedNixOS.outPath}/rednixos-iso-stable.nix"
          ];
      };

      outputsBuilder = channels: {
        devShell = channels.nixpkgs.callPackage nix/devshell.nix {};
      };
    };
}
