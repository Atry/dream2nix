{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  python = config.deps.python;
in {
  imports = [
    ../../drv-parts/mach-nix-xs
  ];

  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      postgresql
      fetchFromGitHub
      ;
    python = nixpkgs.python38;
  };

  name = "odoo";
  version = "16.0";

  mkDerivation = {
    src = config.deps.fetchFromGitHub {
      owner = "odoo";
      repo = "odoo";
      # ref: 16.0
      rev = "2d42fd69cada3b1f2716c3d0a20bec6170f9b226";
      hash = "sha256-ZlPH+RaRZbWooe+kpiFYZtvuVmXtOMHeCW+Z74ZscXY=";
    };
  };

  mach-nix.pythonSources = config.deps.fetchPip {
    inherit (config.deps) python;
    name = config.name;
    requirementsFiles = ["${config.mkDerivation.src}/requirements.txt"];
    hash = "sha256-E9wNvBakm+R5TSsFsnGpSaziYpi2otm0iBiyphUVSFI=";
    maxDate = "2023-01-01";
    nativeBuildInputs = with config.deps; [
      postgresql
    ];
  };

  # Replace some python packages entirely with candidates from nixpkgs, because
  #   they are hard to fix
  mach-nix.substitutions = {
    python-ldap = python.pkgs.python-ldap;
    pillow = python.pkgs.pillow;
  };

  # fix some builds via overrides
  mach-nix.drvs = {
    libsass.mkDerivation = {
      doCheck = false;
      doInstallCheck = l.mkForce false;
    };
    pypdf2.mkDerivation = {
      doCheck = false;
      doInstallCheck = l.mkForce false;
    };
  };
}
