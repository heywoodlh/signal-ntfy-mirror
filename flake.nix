{
  description = "Tools for mirroring notifications between NTFY and Signal";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        ntfy-mirror = pkgs.writeShellScriptBin "main" ''
          if [[ ! -n "$SIGNAL_CLI_DIR" ]]
          then
            [[ -n XDG_DATA_HOME ]] && export SIGNAL_CLI_DIR="$XDG_DATA_HOME/signal-cli"
            [[ ! -n XDG_DATA_HOME ]] && export SIGNAL_CLI_DIR="$HOME/.local/share/signal-cli/data/"
          fi
          # Login if not setup
          [[ ! -e $SIGNAL_CLI_DIR ]] && ${pkgs.signal-cli}/bin/signal-cli --config="$SIGNAL_CLI_DIR" link -n "signal-cli-ntfy" | ${pkgs.coreutils}/bin/tee >(${pkgs.findutils}/bin/xargs -L 1 ${pkgs.qrencode}/bin/qrencode -t utf8)

          # Check for required env vars
          export ERROR=false
          export NTFY_CONF_DIR="/etc/ntfy" # default root user config
          [[ "$EUID" != 0 ]] && export NTFY_CONF_DIR="$HOME/.config/ntfy" # default non-root user config
          mkdir -p "$NTFY_CONF_DIR"
          export NTFY_CLIENT_CONF="$NTFY_CONF_DIR/client.yml"
          [[ ! -n $NTFY_HOST ]] && [[ ! -n "$NTFY_CLIENT_CONF" ]] && printf "No NTFY configuration found at $NTFY_CLIENT_CONF. Please set required NTFY_HOST env variable.\n" && export ERROR=true
          [[ ! -n $NTFY_TOPIC ]] && printf "Please set required NTFY_TOPIC env variable.\n" && export ERROR=true
          [[ ! -n $SIGNAL_DEST ]] && printf "Please set required SIGNAL_DEST env variable.\n" && export ERROR=true
          [[ "$ERROR" == "true" ]] && printf "Error encountered. Exiting." && exit 1
          GROUP_ARG=""
          [[ -n $SIGNAL_GROUP ]] && export GROUP_ARG="-g"

          # If no configuration supplied, use $NTFY_HOST instead
          [[ ! -e "$NTFY_CLIENT_CONF" ]] && printf "default-host: $NTFY_HOST" > "$NTFY_CLIENT_CONF"
          # Subscribe to topic
          ${pkgs.ntfy-sh}/bin/ntfy sub "$NTFY_TOPIC" 'echo "$m" | ${pkgs.signal-cli}/bin/signal-cli --config=$SIGNAL_CLI_DIR send $GROUP_ARG $SIGNAL_DEST --message-from-stdin'
        '';
        base-image = { name, entrypoint, env, }: (pkgs.dockerTools.buildImage {
          name = "${name}";
          tag = "latest";
        
          copyToRoot = pkgs.buildEnv {
            name = "image-root";
            paths = [ entrypoint pkgs.signaldctl ];
            pathsToLink = [ "/bin" ];
          };
        
          runAsRoot = ''
            mkdir -p /data
          '';
        
          config = {
            Env = [ env ];
            Cmd = [ "/bin/main" ];
            WorkingDir = "/data";
            Volumes = { "/data" = { }; };
          };
        });
        ntfy-docker-image = base-image {
          name = "ntfy-mirror";
          entrypoint = ntfy-mirror;
          env = [ "SIGNALD_SOCK" "NTFY_HOST" "NTFY_TOPIC" ];
        };
      in
      {
        devShell = pkgs.mkShell {
          name = "default";
          buildInputs = with pkgs; [
            curl
            ntfy-sh
            qrencode
            signal-cli
            signald
            signaldctl
          ];
        };
        packages = {
          ntfy-mirror = ntfy-mirror;
          ntfy-mirror-image = ntfy-docker-image;
        };

        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}
