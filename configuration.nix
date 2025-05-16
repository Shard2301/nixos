{
  config,
  lib,
  inputs,
  pkgs,
  pkgs-old,
  ...
}: {
  # Import Hardware Scan
  # Run nixos-generate-config to update hardware config
  # ! Doing this will overwrite any manual changes made to the file
  imports = [./hardware-configuration.nix];

  # Lock System State Version to 24.11
  # ! Not locking the version can result in link failures, compilation errors, and general misbehaviour
  # ! This results from when packages and/or bundled dependencies are shipped with different versions, potentially leading to data loss
  # !!! Unless specifically instructed to, never change this value
  # !!! This is not the version of your system; that is managed by flake.nix
  system.stateVersion = "24.11";

  # Use latest version of the Xanmod Kernel
  # Optionally, switch to zen if issues are encountered
  # All avaliable kernels are listed here for reference:
  # https://nixos.wiki/wiki/Linux_kernel
  boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;

  # Use latest avaliable firmware packages
  # This reduces the chance of issues with bleeding edge hardware not functioning due to missing drivers
  hardware.firmware = [pkgs.linux-firmware];

  # Define Extra/Additional Kernel Parameters here
  # These are not kernel configuration options
  # Rather, they are runtime parameters passed to the kernel on each boot
  boot.kernelParams = ["ipv6.disable=1" "mem_sleep_default=s2idle"];

  # Enable EFI Support
  # ! This must be enabled for the system to boot
  boot.loader.efi.canTouchEfiVariables = true;

  # Use the GRand Unified Bootloader (GRUB)
  # systemd-boot is still in infancy and does not have a clean way to interact with Generations
  boot.loader.grub = {
    enable = true;
    memtest86.enable = true;
    device = "nodev"; # Prevents GRUB from installing to the header of the block device, which breaks EFI installations
    efiSupport = true;
    extraEntries = ''
      menuentry "Shutdown" {
      	halt
      }

      menuentry "Reboot to Firmware Interface" {
      	fwsetup
      }
    '';
  };

  # Enable Plymouth boot screen
  # ! Without a theme, Plymouth itself does nothing
  # ! A theme package must be pulled, or a local one must be provided
  boot.plymouth = {
    enable = true;
    themePackages = [pkgs.adi1090x-plymouth-themes];
    theme = "pixels";
  };

  # Enable Support for the software raid subsystem
  # By itself, this does nothing except enable mdadm
  # Raid Array info must be passed to /etc/mdadm.conf via the `boot.swraid.mdadmConf` option
  boot.swraid = {
    enable = true;
    mdadmConf = "ARRAY /dev/md/0  metadata=1.2 UUID=955d263d:cee27b94:18c56abb:ff71dbdb";
  };

  # The following options keep the system healthy and up-to-date
  # As a general rule, they should not need to be changed
  # Enable the Garbage Collection Service
  # This prevents nix from accuring cruft, cleaning stale entries in the nix store at set intervals
  nix.gc = {
    automatic = true;
    persistent = true; # This ensures that Garbage Collection will be triggered, even if missed
    dates = "weekly";
    randomizedDelaySec = "100min";
  };

  # The below options optimize the Nix store to prevent /boot from filling up and breaking the build system
  # Garbage Collection is Routinely Carried out to keep the Nix Store empty as well
  nix.settings.auto-optimise-store = true;
  boot.loader.grub.configurationLimit = 3;
  boot.loader.generationsDir.copyKernels = false;

  # Allow only root and users in the 'wheel' group low-level access to the nix daemon
  nix.settings.trusted-users = ["root" "john"];

  # Enable Experimental Features for Flake Support for version control
  # Also allow unfree packages to be installed globally
  nix.settings.experimental-features = ["nix-command" "flakes"];
  nixpkgs.config.allowUnfree = true;

  # Selectively ignore specific insecure packages
  # These packages are likely dependencies for another package that rely on their featureset still
  # ! Do not add a package to here unless you are absolutely sure you need to
  nixpkgs.config.permittedInsecurePackages = ["openssl-1.1.1w"];

  # Ensure data integrity and health by running 'btrfs scrub' at set intervals
  services.btrfs.autoScrub.enable = true;

  # Periodicially empty SSD Cache to prevent system slowdown
  services.fstrim.enable = true;

  # Enable zram Swap for a compressed ramdisk
  # This is preferred as it is faster than traditional swap and takes up no space
  # A small, unformatted block device is recommend for zram to offload uncompressable pages to
  zramSwap = {
    enable = true;
    priority = 100; # Ensures that zram is used over standard swapspace unless full
    algorithm = "zstd";
    writebackDevice = "/dev/disk/by-partlabel/zramOffload";
  };

  # Enable Hardware Graphics Stack
  # This configuration assumes an Intel Card, specifically a Intel Arc Battlemage
  # ! It is likely your system will boot to a black screen if you do not possess an Intel Arc if you do not modify this configuration
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # Enable graphics for legacy applications and games

    # Install extra packages required for hardware acceleration
    # Double-check the packages you have installed work with your card, or issues may occur
    # Usage of the 'intel-media-sdk' is recommended for older Intel GPUs
    extraPackages = with pkgs; [intel-media-driver intel-vaapi-driver libvdpau-va-gl vpl-gpu-rt];
  };

  # Force Driver in Use
  # This ensures that the correct driver is called to pass load to the card, preventing performance issues
  # iHD is the current intel driver, while i915 is recommended for older cards
  # i915 requires the intel-media-sdk, while iHD requires the intel-media-driver
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  # Only use the intel driver package
  services.xserver.videoDrivers = ["intel"];

  # User mutation is disabled for security reasons
  # By disabling user mutation, any changes made to user accounts are wiped on reboot
  # This limits the damage a malicious binary can do
  users.mutableUsers = false;

  # Configure users accounts
  # Root account is kept disabled for security reasons, as '!' is an impossible hash
  # If needed for debugging, running 'passwd root' will provide temporary access
  users.users.john = {
    hashedPassword = "$6$8VjsfK7V$11teFAqZ9ijQr5L7uDKQlP/ZDOiO78jNOyYL63F4QfSI2U/3uiHqy0599s3BzHgc3HtLwSdkRgobjfbd62Xyq/";
    isNormalUser = true;
    extraGroups = ["wheel" "input" "audio" "video"];
  };

  # Root account is kept disabled for security reasons, as '!' is an impossible hash
  # Temporary root access can be achieved either running 'sudo passwd root' or by altering the password hash
  users.users.root.hashedPassword = "!";

  # Enable printing services
  # This includes the avahi zeroconf daemon
  # Without it, CUPS may or may not work
  services = {
    printing.enable = true;
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
  };

  # Enable Pipewire Sound Server
  # Additional Pipewire Plugins are also enabled alongside it
  # Without them, audio would not work as very little natively supports PipeWire
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true; # Ensure sound works for Steam Games
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # Configure the sudo security package
  # Care must be taken when configuring sudo, as mis-configuration could break the system severely
  # ! Do not touch this unless required
  security.sudo = {
    execWheelOnly = true;
    extraConfig = ''
      Defaults insults
      Defaults editor="${pkgs.vim}/bin/vim"
      Defaults env_reset,pwfeedback
    '';
  };

  # Configure Networking
  # NetworkManager is used as it is the simpliest solution and works with little futz, even for obscure network types
  # Also define a hostname. Ensure this has a matching equivalent in flake.nix
  networking.hostName = "nixos-desktop";
  networking.networkmanager = {
    enable = true;
    plugins = [pkgs.networkmanager-openconnect];
  };

  # Configure the Firewall, ensuring that it is enabled
  # The firewall uses IPTables for the backend by default
  # Add any additional rules not covered by exposed NixOS Configuration options below
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [22000]; # Syncthing Transfer
    allowedUDPPorts = [22000 21027]; # Syncthing Transfer & Discovery
  };

  # Ensure dbus is functioning and use the new broker implementation
  # The broker implementation is designed to be more stable and efficient
  # If issues arise, simply comment the line out
  services.dbus = {
    enable = true;
    implementation = lib.mkDefault "broker";
  };

  # Enable the power-profiles-daemon service for managing power settings
  services.power-profiles-daemon.enable = true;

  # Enable the firmware-updater daemon for managing compatible devices
  services.fwupd.enable = true;

  # Enable the GNUPG Agent
  # This is required for various forms of authentication
  # Some software may break without it
  programs.gnupg.agent.enable = true;

  # Configure git
  # By default, git will complain if invoked without configuring it
  # This ensures that needless configuration of git isn't required
  programs.git = {
    enable = true;
    config = {
      init.defaultBranch = "main";
      user.name = "crash-dump";
      user.email = "github@crashdump.8shield.net";
      advice.addignoredfile = false; # Supresses the irritating warnings when using a .gitignore file
    };
  };

  # Set up environment variables
  # Additional configuration options referring to system configuration may also be found here
  # ! Do not touch an option if you do not understand it. Things may break if you do.
  environment = {
    localBinInPath = true; # Add $HOME/.local/bin to $PATH
    homeBinInPath = true; # Add $HOME/bin to $PATH
    variables = {
      # Set vim as default console editor
      EDITOR = "vim";
      VISUAL = "vim";
      SUDO_EDITOR = "vim";
    };
  };

  # Set timezone using UNIX Standard Format
  time.timeZone = "Pacific/Auckland";

  # Define System Locale options
  # This includes things such as fonts, language, keyboard layout, etc.
  # Options may be overriden indepently by other options in userspace when needed
  i18n.defaultLocale = "en_NZ.UTF-8";
  i18n.extraLocales = ["en_US.UTF-8"]; # Steam may break without this

  # Configure options for TTY Consoles
  # This primarily configures the font package used for better readability
  console = {
    packages = [pkgs.terminus_font];
    font = "${pkgs.terminus_font}/share/consolefonts/ter-132b.psf.gz";
    keyMap = lib.mkDefault "us"; # ! Forces a US 104-key keymap. Comment out if you use a different layout
    useXkbConfig = true; # Use xkb.options mappings in tty, if present
  };

  # Configure System Fonts
  # Atkinson fonts are chosen for their ease of use an ability to read
  # Additional fonts are also used to supplement missing fonts
  fonts.fontDir.enable = true;
  fonts.packages = with pkgs; [
    noto-fonts # Fallback font
    meslo-lgs-nf # Patched specifically for P10K
    hachimarupop # Handwriting font

    # Easy to read fonts
    # To be used as main system fonts where possible
    atkinson-hyperlegible
    atkinson-monolegible
  ];

  # Using fontconfig, declare default fonts
  # These fonts will be automatically set as default for any program that supports fontconfig
  # They may be overridden on a case-by-case basis
  fonts.fontconfig.defaultFonts = {
    serif = ["Noto Serif"];
    sansSerif = ["Atkinson Hyperlegible"];
    monospace = ["Atkinson Monolegible"];
    emoji = ["Noto Color Emoji"];
  };

  # Enable Flatpak
  # Additional Setup is required to access flathub
  services.flatpak.enable = true;

  # Declare System-wide programs in this block
  # All programs declared here are avaliable system wide, accessible by all users
  # Some programs may be called seperately via an exposed configuration option instead
  environment.systemPackages = with pkgs; [
    # Editors
    vim

    # Tools
    wget
    tree
    file
    power-profiles-daemon
    android-tools # adb and fastboot

    # File System Tools
    btrfs-progs
    dosfstools
    e2fsprogs

    # Hardware Info
    pciutils
    usbutils
    coreutils
    efibootmgr
    fwupd

    # Diagnostic Tools
    nvme-cli
    smartmontools
    iozone
    fio

    # Monitoring Tools
    lshw
    sysstat
    iotop
    btop
    htop
    lm_sensors
    ncdu

    # Miscellaneous
    tmux # Terminal Multiplexer
    wev # Wayland implementation of X.Org's xev command
    xdg-utils
    flatpak-xdg-utils

    # Libraries
    libarchive
    zenity
    glib
  ];

  # User Packages are defined here on a per-user basis
  # User packages are restricted to individual users, with other users unable to access these programs
  # Any programs called via an exposed option are excluded from this
  users.users.john.packages = with pkgs; [
    # CLI Applications
    fastfetch # View System Info
    zoxide # Smart cd
    lsd # better 'ls' command
    clifm
    ffmpeg
    bat # better 'cat' command
    speedtest-cli
    p7zip # 7zip implementation
    alejandra # Nix Code Formatter
    imv # image viewer
    imagemagick # cli image manipulation suite

    # Terminal Prompts
    oh-my-posh # P10K Replacement

    # Notetaking
    obsidian
    obsidian-export # For exporting Vault to markdown files

    # Image Editing
    krita
    inkscape
    gimp3

    # Backup Software
    duplicacy
    rclone
    syncthing

    # Gaming
    prismlauncher # Minecraft
    itch # Itch.io games
    lutris # For non-steam games

    # Password Managers
    bitwarden
    proton-pass

    # Email Client(s)
    protonmail-desktop

    # Development
    sublime4

    # Office Software
    libreoffice-qt6-fresh # Main version is broken, constantly crashes
    onlyoffice-desktopeditors

    # Libraries
    jre8 # Java Runtime
  ];

  # Enable and configure Steam Gaming Client
  # Additional Packages are pulled down, exclusive for Steam's use
  programs.steam = {
    enable = true;
    protontricks.enable = true; # Don't disable this unless you have a good reason to
    extraCompatPackages = with pkgs; [
      proton-ge-bin
      steamtinkerlaunch
    ];
    extraPackages = with pkgs; [
      gamescope
      gamemode
      mangohud
    ];
  };

  # Enable and configure ZSH
  # ! Essential options only for global ZSH configuration should be added here to avoid file bloat
  # Alternatively, place configuration in zsh.nix, and source it
  programs.zsh = {
    enable = true;
    promptInit = ''
      # Initalize oh-my-posh transient shell configuration
      eval "$(oh-my-posh init zsh --config $HOME/nix/dotfiles/oh-my-posh/zen.toml)"

      # Initalize zoxide on shell load
      eval "$(zoxide init zsh)"
    '';
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    autosuggestions.enable = true;
    autosuggestions.strategy = ["completion"];
    enableBashCompletion = true;
    histSize = 10000;
    shellAliases = {
      # Short-form aliases for common uses of ls/lsd
      l = "lsd -alh";
      ll = "lsd -l";
      lt = "lsd --tree";

      # Alias to invoke lsd whenever ls is called
      ls = "lsd";

      # Call zoxide when invoking the 'cd' command
      cd = "z";
      cdi = "zi";

      # Invoke $EDITOR with single command
      edit = "$EDITOR";

      # Alias to shortern the use of the 'realpath' command and provide a convient shorthand
      rp = "realpath";
      rpc = "realpath ."; # Always prints the true path of the current working directory
    };
    setOptions = [
      "AUTO_CD"
      "HIST_IGNORE_DUPS"
      "SHARE_HISTORY"
      "HIST_FCNTL_LOCK"
    ];
  };

  # Enable the GNOME Display Manager
  # This is used instead of the Cosmic Greeter, as the Cosmic Greeter is currently buggy and crash-prone
  services.xserver = {
    enable = true;
    displayManager.gdm.enable = true;
  };

  # Enable the Cosmic Desktop
  # This is a monolithic package for the cosmic desktop, bundling everything in one
  # Additionally, the cosmic greeter is force-disabled due to stability issues (see above)
  services.desktopManager.cosmic = {
    enable = true;
    xwayland.enable = true;
  };
  services.displayManager.cosmic-greeter.enable = false;
}
