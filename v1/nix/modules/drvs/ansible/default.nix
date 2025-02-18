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

  # use lock file to manage hash for fetchPip
  lock.fields.fetchPipHash =
    config.lock.lib.computeFODHash config.mach-nix.pythonSources;

  deps = {nixpkgs, ...}: {
    python = nixpkgs.python39;
    inherit (nixpkgs.writers) writePython3;
  };

  name = "ansible";
  version = "2.7.1";

  mkDerivation = {
    preUnpack = ''
      export src=$(ls ${config.mach-nix.pythonSources}/names/${config.name}/*);
    '';
  };

  buildPythonPackage = {
    format = "setuptools";

    pythonImportsCheck = [
      config.name
    ];
  };

  mach-nix.pythonSources = config.deps.fetchPip {
    inherit python;
    name = config.name;
    requirementsList = ["${config.name}==${config.version}"];
    hash = config.lock.content.fetchPipHash;
    maxDate = "2023-01-01";
  };
}
