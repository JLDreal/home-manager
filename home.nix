{ config, pkgs, unstablePkgs, lib, ... }:
let
  # ===== CONFIGURABLE MODEL SETTINGS =====
  rustModel = {
    name = "codegemma:2b";  # Options: "starcoder2:3b", "deepseek-coder:1.3b", "codellama:7b"
    provider = "ollama";      # "ollama" or "huggingface"
  };

in
{
  # ========== Basic Configuration ==========
  home.username = "dev";
  home.homeDirectory = "/home/dev";
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;

  # ========== Package List ==========
  home.packages = with pkgs; [
    unstablePkgs.jujutsu
    btop
    dwarf-fortress
    unstablePkgs.vscodium
    unstablePkgs.minecraft
    unstablePkgs.radicle-node
    gnumake
    gh
    unstablePkgs.rustup
    unstablePkgs.rustc
    zed-editor
    keepass
    tuisky
    typst
    obsidian
    tt
    nix-init

    ## filemanager dep
    ranger
        # Optional dependencies for better functionality
        w3m # For image previews
        ffmpegthumbnailer # For video thumbnails
        poppler_utils # For PDF previews (pdftotext)
        highlight # For syntax highlighting
        atool # For archive previews
        mediainfo # For media file info
  ];

  # ========== Ranger filemanager ==========
  # Create desktop entry
  xdg.desktopEntries.ranger = {
    name = "Ranger";
    genericName = "File Manager";
    comment = "Terminal-based file manager with VI key bindings";
    exec = "${pkgs.kitty}/bin/kitty -e ranger %F";  # Changed %U to %F
    terminal = false;  # Important change (explained below)
    categories = [ "FileManager" "Utility" ];  # Simplified categories
    mimeType = [ "inode/directory" ];  # Removed gnome-specific type
    icon = "utilities-terminal";
    startupNotify = false;  # Added for better behavior
    noDisplay = false;  # Ensures it shows in menus
  };
  xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "inode/directory" = [ "ranger.desktop" ];
      };
    };

    # Set MIME associations manually
    xdg.configFile."mimeapps.list".text = ''
      [Default Applications]
      inode/directory=ranger.desktop
      application/x-gnome-saved-search=ranger.desktop
    '';
    home.activation.setRangerAsDefault = ''
        ${pkgs.xdg-utils}/bin/xdg-mime default ranger.desktop inode/directory
      '';

    # Ranger configuration (same as before)
    xdg.configFile."ranger/rc.conf".text = ''
      set show_hidden true
      set preview_images true
      set preview_images_method w3m
      set sort natural
    '';

    ## ranger for zed


  # ========== Starship Prompt ==========

    programs.starship = {
      enable = true;
      settings = {
        # Core Formatting
        add_newline = false;
        format = "$username$hostname$nix_shell$git_branch$git_commit$git_state$git_status$directory$jobs $cmd_duration$character";

        # Baduk Git Theme
        git_branch = {
          format = ''[●○ @ \($branch\)]($style)'';
          style = "bold";
          symbol = "";
        };
        git_status = {
          conflicted = "✖";  # Atari!
          ahead = "▲";       # Winning
          behind = "▼";      # Losing
          diverged = "⏣";    # Seki (stalemate)
          staged = "○";      # White stone (staged)
          modified = "●";    # Black stone (unstaged)
          untracked = "◻";   # Empty intersection
          stashed = "≡";     # Ko fight
          style = "dimmed";
        };
        directory = {
          format = ''[\($path\)]($style)'';
          style = "blue dimmed";
          truncation_length = 3;
          substitutions = {
            "Documents" = "D";
            "Projects" = "P";
            "Downloads" = "DL";
          };
        };

        # User/System Info
        username = {
          disabled = false;
          style_user = "bright-white bold";
          style_root = "bright-red bold";
          format = "[$user]($style)";
          show_always = true;
        };
        hostname = {
          disabled = false;
          format = "[@$hostname]($style)";
          style = "bright-green bold";
        };

        # Shell/System
        shell = {
          disabled = false;
          format = "$indicator";
          fish_indicator = ''[●⋉](bold)'';
          bash_indicator = ''[🌀](bold #9a77cf)'';
        };
        cmd_duration = {
          format = ''[$duration]($style)'';
          style = "yellow";
          min_time = 5000;
        };

        # Optional: Nix Shell Indicator
        nix_shell = {
          disabled = false;
          format = "[via  $name]($style)";
          style = "bold purple";
        };



      };
    };


  # ========== SSH Agent ==========
  programs.ssh = {
    enable = true;
    extraConfig = ''
      AddKeysToAgent yes
      IdentityAgent ${config.home.homeDirectory}/.ssh/agent.sock
    '';
  };

  # Systemd service with correct syntax
  systemd.user.services.ssh-agent = {
    Unit = {
      Description = "SSH Authentication Agent";
      Documentation = "man:ssh-agent(1)";
    };
    Service = {
      Type = "simple";
      ExecStart = ''${pkgs.openssh}/bin/ssh-agent -D -a ${config.home.homeDirectory}/.ssh/agent.sock '';
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # Environment variables
  home.sessionVariables = {
    SSH_AUTH_SOCK = "${config.home.homeDirectory}/.ssh/agent.sock";
  };

  # Create directory and ensure proper permissions
  home.activation.setupSshAgent = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p ${config.home.homeDirectory}/.ssh
    chmod 700 ${config.home.homeDirectory}/.ssh
  '';

  # ========== Zed Editor ==========
  programs.zed-editor = {
    enable = true;
    extensions = ["nix" "toml" "elixir" "make" "sql"];

    userSettings = {
      fileManager = "ranger";
      assistant = {
              enabled = true;
              version = "2";
              default_open_ai_model = null;
              default_model = {
                provider = rustModel.provider;
                model = rustModel.name;
              };
            };



    # Node.js Configuration
    node = {
      path = lib.getExe pkgs.nodejs;
      npm_path = lib.getExe' pkgs.nodejs "npm";
    };

    # General Settings
    hour_format = "hour24";
    auto_update = false;
    vim_mode = false;
    load_direnv = "shell_hook";
    base_keymap = "VSCode";

    # Terminal Configuration
    terminal = {
      alternate_scroll = "off";
      blinking = "off";
      copy_on_select = false;
      dock = "bottom";

      detect_venv = {
        on = {
          directories = [".env" "env" ".venv" "venv"];
          activate_script = "default";
        };
      };

      env = { TERM = "kitty"; };
      font_family = "FiraCode Nerd Font";
      font_features = null;
      font_size = null;
      line_height = "comfortable";
      option_as_meta = false;
      button = false;
      shell = "system";
      toolbar = { title = true; };
      working_directory = "current_project_directory";
    };

    # Language Server Protocol (LSP) Configuration
    lsp = {
      rust-analyzer = {
        binary = {
          path = lib.getExe pkgs.rust-analyzer;
          path_lookup = true;
        };
      };

      nix = {
        binary.path_lookup = true;
      };

      elixir-ls = {
        binary.path_lookup = true;
        settings.dialyzerEnabled = true;
      };
    };

    # Language-specific Settings
    languages = {
      "Elixir" = {
        language_servers = ["!lexical" "elixir-ls" "!next-ls"];
        format_on_save = {
          external = {
            command = "mix";
            arguments = ["format" "--stdin-filename" "{buffer_path}" "-"];
          };
        };
      };

      "HEEX" = {
        language_servers = ["!lexical" "elixir-ls" "!next-ls"];
        format_on_save = {
          external = {
            command = "mix";
            arguments = ["format" "--stdin-filename" "{buffer_path}" "-"];
          };
        };
      };
    };

    # UI Configuration
    theme = {
      mode = "dark";
      light = "One Light";
      dark = "One Dark";
    };

    show_whitespaces = "all";
    ui_font_size = 16;
    buffer_font_size = 16;
  };
  };
}
