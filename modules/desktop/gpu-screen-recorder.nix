# `caelestia record` shells out to gpu-screen-recorder, which needs
# CAP_SYS_ADMIN to read KMS planes off /dev/dri/cardN. With no capability
# wrapper installed it falls back to running gsr-kms-server under pkexec, so
# every recording opens a password prompt.
#
# This option is the wrapper, not the package: gpu-screen-recorder already
# wraps itself with `--prefix PATH : /run/wrappers/bin` and only
# `--suffix PATH : $out/bin`, so it looks for gsr-kms-server in the wrapper
# directory first and falls back to its own uncapable copy. Creating the
# wrapper there is therefore enough to reach the copy inside caelestia's
# closure as well -- nothing has to override caelestia to get it.
#
# A capability on one helper, rather than a polkit rule letting the user run
# it as root without a password: cap_sys_admin on the KMS server is the narrow
# half of what passwordless pkexec would hand over.
{
  programs.gpu-screen-recorder.enable = true;
}
