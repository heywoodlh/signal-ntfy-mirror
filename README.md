## signal-ntfy-mirror

Mirror notifications from a single NTFY topic to a single Signal user/group.

## Development setup

In another terminal, set some environment variables:

```
export NTFY_HOST="http://ntfy"
export NTFY_TOPIC="ssh-notifications"
export SIGNAL_CLI_DIR="$HOME/tmp/signal-cli"
export SIGNAL_DEST="+10000000000"
```

Then, run the mirroring script:

```
nix run .#ntfy-mirror
```
