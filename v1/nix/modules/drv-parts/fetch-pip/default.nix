{
  config,
  lib,
  drv-parts,
  ...
}: let
  l = lib // builtins;

  fetchPip = import ../../pkgs/fetchPip {
    inherit
      (config.deps)
      buildPackages
      python
      ;
  };
in {
  imports = [
    drv-parts.modules.drv-parts.mkDerivation
  ];

  deps = {nixpkgs, ...}:
    l.flip l.mapAttrs (_: l.mkDefault) {
      inherit
        (nixpkgs)
        buildPackages
        python
        ;
    };

  package-func.func = fetchPip;
  package-func.args = config.fetch-pip;
}
