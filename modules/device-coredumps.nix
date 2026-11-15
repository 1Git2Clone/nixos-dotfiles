# Kernel device dumps expire in memory; copy them out on the add event.
{ pkgs, ... }:
let
  saveDump = pkgs.writeShellApplication {
    name = "save-device-coredump";
    runtimeInputs = [ pkgs.coreutils ];
    text = builtins.readFile ./scripts/save-device-coredump.sh;
  };
in
{
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="devcoredump", TAG+="systemd", ENV{SYSTEMD_WANTS}+="save-device-coredump@%k.service"
  '';

  systemd.services."save-device-coredump@" = {
    description = "Persist kernel device coredump %i";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${saveDump}/bin/save-device-coredump /sys/class/devcoredump/%i /var/lib/devcoredumps";
      StateDirectory = "devcoredumps";
      StateDirectoryMode = "0700";
      UMask = "0077";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };
}
