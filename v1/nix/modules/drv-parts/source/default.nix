{
  config,
  options,
  lib,
  drv-parts,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options.source = l.mkOption {
    type = t.submodule [
      drv-parts.modules.drv-parts.public
    ];
    description = ''
      Specify the source of the package via a drv-parts module
    '';
  };

  # add `source` to config.deps
  config.deps.source = l.mkOptionDefault config.source.public;
}
