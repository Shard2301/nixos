{
  config,
  lib,
  pkgs,
  ...
}: {
  # Run duplicacy as a systemd service
  systemd.user.services.duplicacy-backup = {
    description = "automated backup service";
    path = [pkgs.bash pkgs.duplicacy pkgs.libnotify];
    serviceConfig = {
      WorkingDirectory = "/home/john";
      ExecStart = "/home/john/bin/duplicacy.sh";
    };
    wantedBy = ["default.target"];
  };

  # Run rclone as a systemd service
  systemd.user.services.rclone-sync = {
    description = "automated b2 sync platform";
    path = [pkgs.bash pkgs.rclone pkgs.libnotify];
    serviceConfig = {
      WorkingDirectory = "/home/john";
      ExecStart = "/home/john/bin/rclone.sh";
    };
    wantedBy = ["default.target"];
  };

  # Run daily timers for backup
  systemd.user.timers.duplicacy-backup = {
    timerConfig = {
      Unit = "duplicacy-backup.service";
      OnBootSec = "5m";
      OnUnitActiveSec = "1d";
    };
    wantedBy = ["default.target"];
  };

  systemd.user.timers.rclone-sync = {
    timerConfig = {
      Unit = "duplicacy-backup.service";
      OnBootSec = "5m";
      OnUnitActiveSec = "1d";
    };
    wantedBy = ["default.target"];
  };
}
