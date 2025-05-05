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
  ];

  # ========== Starship Prompt ==========

    programs.starship = {
      enable = true;
      settings = {
        # Core Formatting
        add_newline = false;
        format = "$username$hostname$nix_shell$vcs_indicator $git_branch$git_commit$git_state $git_status$directory$jobs $cmd_duration$character";

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

        # dynamic vcs support
        vcs_indicator = {
                description = "Dynamic VCS state indicator (Git/JJ)";
                command = ''
                  if command -v git >/dev/null && git rev-parse --is-inside-work-tree 2>/dev/null | grep -q true; then
                    # Git repo logic
                    if git ls-files --unmerged | grep -q .; then
                      echo "✖"  # Conflict
                    elif ! git diff --quiet 2>/dev/null; then
                      if git diff --cached --quiet 2>/dev/null; then
                        echo "●"  # Unstaged
                      else
                        echo "○"  # Staged
                      fi
                    else
                      echo "∿"   # Clean
                    fi
                  elif command -v jj >/dev/null && jj log -r @ 2>/dev/null | grep -q .; then
                    # JJ repo logic
                    if jj diff --stat @ 2>/dev/null | grep -q conflict; then
                      echo "✖"  # Conflict
                    elif jj diff --stat @ 2>/dev/null | grep -q changed; then
                      echo "●"  # Changes
                    else
                      echo "∿"  # Clean
                    fi
                  else
                    echo ""  # No VCS
                  fi
                '';
                when = ''command -v git >/dev/null || command -v jj >/dev/null'';
                format = ''[$output]($style)'';
                style = "bold";
                shell = ["bash" "fish" "zsh"];
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

      env = { TERM = "alacritty"; };
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
