# SolidCraft assistant

This bundle is the **visible switch** for the SolidCraft ACP integration. It is
installed in the `desktop` profile so it appears in **Plugins**. Its patch
inserts one no-op plugin (`solidcraft-switch`) from `index.js`; that plugin
does nothing, so enabling the bundle does not change the Desktop assistant.

## How it works

The kit writes `dsh-acp.cmd`, which SolidCraft launches. Before starting DSH it
checks two things in the desktop profile:

1. `dsh.profile.bundles` still contains `dsh-solidcraft-bundle`;
2. `profiles\desktop\node_modules\dsh-solidcraft-bundle\solidcraft.patch.yml`
   exists.

When both are true, the launcher runs:

```text
dsh --profile acp --patch <...>\solidcraft.patch.yml
```

Otherwise it runs plain `dsh --profile acp`. The overlay adds the SolidCraft
persona and routes sessions through the DeepSeek account login; it applies to
the `acp` profile only.

The no-op row also means the plugin market reports the bundle as a real, loaded
plugin instead of an empty patch that "will not load". The row has no services,
no UI and no tools.

## Plugins page

- **Enabled**: the next launch of the SolidCraft agent gets the overlay.
- **Disabled**: the launcher runs plain `dsh --profile acp`; SolidCraft still
  connects, but the model has no SolidCraft persona and falls back to the
  API-key route, so the first prompt fails with `no API key for provider route
  "deepseek-official"`. Disabling is only useful to turn the integration off.
- **Remove**: uninstalls the package. The launcher then runs plain
  `dsh --profile acp`, which is the same as disabled.

The `acp` profile has no copy of this bundle, so there is no second install to
clean up. The next Connect after enabling, disabling or removing picks up the
change; a running connection keeps the configuration it started with.

## Requirements

- DSH Desktop installed and signed in with a DeepSeek account.
- SolidCraft's agent command points at the kit's `dsh-acp.cmd`, not at
  `dsh --profile acp` directly.
- SolidCraft has `solidcraft-cli.exe` next to `solidcraft.exe` for the design
  tools.

## Limitations

- The launcher checks the **desktop** profile's manifest. If the desktop
  profile is reset or DSH is reinstalled, re-run the kit's installer.
- The launcher records the DSH home at install time; a custom `DSH_HOME` needs
  a reinstall.
- Enabling or disabling while SolidCraft is connected does not reconfigure the
  live agent process; reconnect or send a new message after the next Connect.
