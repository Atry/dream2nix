{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  cfg = config.lock;

  # LOAD
  file = cfg.repoRoot + cfg.lockFileRel;
  data = l.fromJSON (l.readFile file);
  fileExist = l.pathExists file;

  refresh = config.deps.writePython3Bin "refresh" {} ''
    import tempfile
    import subprocess
    import json
    from pathlib import Path

    refresh_scripts = json.loads('${l.toJSON cfg.fields}')  # noqa: E501
    repo_path = Path(subprocess.run(
        ['git', 'rev-parse', '--show-toplevel'],
        check=True, text=True, capture_output=True)
        .stdout.strip())
    lock_path_rel = Path('${cfg.lockFileRel}')
    lock_path = repo_path / lock_path_rel.relative_to(lock_path_rel.anchor)


    def run_refresh_script(script):
        with tempfile.NamedTemporaryFile() as out_file:
            subprocess.run(
                [script],
                check=True, shell=True, env={"out": out_file.name})
            return json.load(out_file)


    def run_refresh_scripts(refresh_scripts):
        """
          recursively iterate over a nested dict and replace all values,
          executable scripts, with the content of their $out files.
        """
        for name, value in refresh_scripts.items():
            if isinstance(value, dict):
                refresh_scripts[name] = run_refresh_scripts(value)
            else:
                refresh_scripts[name] = run_refresh_script(value)
        return refresh_scripts


    lock_data = run_refresh_scripts(refresh_scripts)
    with open(lock_path, 'w') as out_file:
        json.dump(lock_data, out_file, indent=2)
  '';

  computeFODHash = fod: let
    unhashedFOD = fod.overrideAttrs (old: {
      outputHash = l.fakeSha256;
      name = "${old.name}-UNHASHED_FOD";
    });
    drvPath = l.unsafeDiscardStringContext unhashedFOD.drvPath;
  in
    config.deps.writePython3 "update-FOD-hash-${config.name}" {} ''
      import json
      import os
      import re
      import subprocess
      import sys

      out_path = os.getenv("out")
      drv_path = "${drvPath}"  # noqa: E501
      nix_build = ["${config.deps.nix}/bin/nix", "build", "-L", drv_path]  # noqa: E501
      with subprocess.Popen(nix_build, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True) as process:  # noqa: E501
          for line in process.stdout:
              line = line.strip()
              print(line)
              search = r"error: hash mismatch in fixed-output derivation '.*UNHASHED_FOD.*':"  # noqa: E501
              if re.match(search, line):
                  print("line matched")
                  specified = next(process.stdout).strip().split(" ", 1)
                  got = next(process.stdout).strip().split(" ", 1)
                  assert specified[0].strip() == "specified:"
                  assert got[0].strip() == "got:"
                  checksum = got[1].strip()
                  print(f"Found hash: {checksum}")
                  with open(out_path, 'w') as f:
                      json.dump(checksum, f, indent=2)
                  exit(0)
      print("Could not determine hash", file=sys.stdout)
      exit(1)
    '';

  errorMissingFile = ''
    The lock file ${cfg.lockFileRel} for drv-parts module '${config.name}' is missing, please update it.
    To create the lock file, execute:
      bash -c $(nix-build ${config.lock.refresh.drvPath})/bin/refresh
  '';

  errorOutdated = path': let
    path = l.concatStringsSep "." path';
  in ''
    The lock file ${cfg.lockFileRel} for drv-parts module '${config.name}' misses expected attribute `${path}`.
    To update the lock file, execute:
      bash -c $(nix-build ${config.lock.refresh.drvPath})/bin/refresh
  '';

  fileContent =
    if ! fileExist
    then throw errorMissingFile
    else data;

  loadField = path: val:
    if l.hasAttrByPath path fileContent
    then (l.getAttrFromPath path fileContent)
    else throw (errorOutdated path);

  loadedContent =
    l.mapAttrsRecursiveCond
    (val: ! l.isDerivation val)
    loadField
    cfg.fields;
in {
  imports = [
    ./interface.nix
  ];

  config = {
    lock.refresh = refresh;

    lock.content = loadedContent;

    lock.lib = {inherit computeFODHash;};

    deps = {nixpkgs, ...}:
      l.mapAttrs (_: l.mkDefault) {
        inherit (nixpkgs) nix;
        inherit (nixpkgs.writers) writePython3Bin;
      };
  };
}
