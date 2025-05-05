{ config, pkgs, unstablePkgs, lib, ... }:
let
  # ===== CONFIGURABLE MODEL SETTINGS =====
  rustModel = {
    name = "starcoder2:3b";  # Options: "starcoder2:3b", "deepseek-coder:1.3b", "codellama:7b"
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
    ollama
    tt
    nix-init
  ];

  # ========== Starship Prompt ==========
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$shlvl$username$hostname$nix_shell$git_branch$git_commit$git_state$git_status$directory$jobs$cmd_duration$character";
      shlvl = {
        disabled = false;
        symbol = "666";
        style = "bright-red bold";
      };
      shell = {
        disabled = false;
        format = "$indicator";
        fish_indicator = "";
      };
      username = {
        style_user = "bright-white bold";
        style_root = "bright-red bold";
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
        enable = true;
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

# Ollama configuration
  systemd.user.services.ollama = {
    enable = true;
    Unit = {
      Description = "Ollama AI service";
      After = "network.target";
    };
    Service = {
      ExecStart = "${pkgs.ollama}/bin/ollama serve";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  home.activation.ollamaPull = lib.hm.dag.entryAfter ["writeBoundary"] ''
    ${pkgs.ollama}/bin/ollama serve &
    echo "Checking for Ollama model '"${rustModel.name}"'..."
    if ! ${pkgs.ollama}/bin/ollama list | ${pkgs.gnugrep}/bin/grep -q "${rustModel.name}" ; then
      echo "Pulling '"${rustModel.name}"' model (this may take several minutes)..."
      ${pkgs.ollama}/bin/ollama pull "${rustModel.name}"
    else
      echo "Model '"${rustModel.name}"' already exists"
    fi
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

      node = {
        path = lib.getExe pkgs.nodejs;
        npm_path = lib.getExe' pkgs.nodejs "npm";
      };

      hour_format = "hour24";
      auto_update = false;
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

      lsp = {
        rust-analyzer = {
          binary = {
            path = lib.getExe pkgs.rust-analyzer;
            path_lookup = true;
          };
        };
        nix = { binary = { path_lookup = true; }; };
        elixir-ls = {
          binary = { path_lookup = true; };
          settings = { dialyzerEnabled = true; };
        };
      };

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

      vim_mode = false;
      load_direnv = "shell_hook";
      base_keymap = "VSCode";
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
