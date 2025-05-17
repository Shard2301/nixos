{
  inputs,
  config,
  lib,
  pkgs,
  home-manager,
  ...
}: {
  # Username and Home Directory that home-manager should manager
  home.username = "john";
  home.homeDirectory = "/home/john";

  # Allow home-manager to install and manage itself
  programs.home-manager.enable = true;

  # This variable declares the version of home-manager upon initial install
  # This ensures compatibility in case of breaking changes introduced between versions
  # Unless you have a need to, do not modify this value.
  home.stateVersion = "24.11";

  # Enable and configure ghostty
  programs.ghostty.enable = true;
  programs.ghostty.settings = {
    # Launch ZSH on shell initialization calls
    command = "zsh";

    # Font Configuration
    font-family = "MesloLGS NF"; # MesloLGS NerdFont Patched
    font-size = 14.5; # A more reasonable size for a 1440p display
  };

  # Enable the Syncthing user-level service
  services.syncthing.enable = true;

  # Enable and configure the yt-dlp download client
  programs.yt-dlp = {
    enable = true;
    extraConfig = ''
      -o "%(title)s.%(ext)s"
      --embed-metadata
    '';
  };

  # Enable and configure mpv
  programs.mpv = {
    enable = true;
    config = {
      image-display-duration = 0;
    };
  };

  # Allow home-manager to manage beets music library and tagging
  programs.beets.enable = true;
}
