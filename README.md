# DSH × SolidCraft kit

Makes a DSH installation ready for SolidCraft's Assistant **and** shows the
integration in DSH's **Plugins** page, where it can be enabled, disabled and
removed like any other bundle.

Version 0.2.2.

## What it changes

- Installs `dsh-solidcraft-bundle` into the **desktop profile**. It inserts one
  no-op plugin (`solidcraft-switch`) so the Plugins page reports a real, loaded
  bundle; that plugin does nothing, so the Desktop assistant is unchanged.
- Writes `<InstallDir>\dsh-acp.cmd`, a launcher for SolidCraft. Before starting
  DSH it checks whether the switch is enabled in the desktop profile:
  - enabled  -> `dsh --profile acp --patch <bundle>\solidcraft.patch.yml`
  - disabled or removed -> plain `dsh --profile acp`
- `solidcraft.patch.yml` (inside the bundle) adds the SolidCraft persona and
  routes sessions through `deepseek-account` / `deepseek-flash`, matching the
  Desktop app's login. It is applied to the `acp` profile only.

The `acp` profile itself stays clean: no second copy of the bundle is
installed there. The launcher is the only bridge.

## Manage it in Plugins

DSH: **Settings → Plugins → SolidCraft assistant**

- **Enabled**: the next SolidCraft Connect gets the SolidCraft persona and the
  account route.
- **Disabled**: the launcher runs plain `dsh --profile acp`; SolidCraft still
  connects, but the first prompt fails with `no API key for provider route
  "deepseek-official"` because no API key is configured. Disabling turns the
  integration off.
- **Remove**: uninstalls the package; the launcher falls back to plain
  `dsh --profile acp`, the same as disabled.

A running SolidCraft connection keeps the configuration it started with;
reconnect after changing the switch. The first install may need one DSH
restart before the switch's no-op plugin row is listed as loaded; the launcher
and the SolidCraft agent work either way.

## Requirements

- Windows 10 or 11, Windows PowerShell 5.1 (`install.cmd` bypasses the
  execution policy for this script only).
- DSH Desktop installed and signed in with a DeepSeek account. The listener
  expects the desktop profile to exist: start the Desktop app once before
  installing.
- SolidCraft 0.41 or newer with `solidcraft-cli.exe` next to `solidcraft.exe`.
  Without the CLI the chat connects but cannot touch the design.

No administrator rights are needed.

## Install

Extract the kit anywhere (paths with spaces are fine) and run:

```powershell
.\install.cmd
```

Options:

```text
-DshCmd <path to dsh.cmd>     default: the Desktop install, then dsh on PATH
-DshHome <path>               default: $env:DSH_HOME, then %USERPROFILE%\.dsh
-InstallDir <path>            default: %LOCALAPPDATA%\DSH-SolidCraft
-NoClipboard                  do not copy the command to the clipboard
```

The installer:

1. copies the bundle to `<InstallDir>\bundle`;
2. backs up the desktop and acp profile manifests and lockfiles to
   `<InstallDir>\backup`;
3. installs and enables the switch in the desktop profile;
4. removes the old acp copy installed by kit 0.1.x, if any;
5. writes the launcher and verifies that the switch is enabled, the overlay
   composes and the launcher starts.

Re-running it is safe and idempotent.

## SolidCraft (one time per installation)

`Preferences → AI → Agents → Add agent… → Custom command`

- Name: `DeepSeek Harness`
- Command: the path the installer printed, normally
  `C:\Users\<you>\AppData\Local\DSH-SolidCraft\dsh-acp.cmd`

Then select it in the Assistant header and press **Connect**.

If you previously used the kit's old launcher (or a hand-written
`dsh --profile acp` command), edit the agent's command to this launcher,
otherwise the Plugins switch cannot control it.

## Distribute

1. Zip the whole `dsh-solidcraft-kit` folder. Do not include a `node_modules`
   folder, a `backup` folder, or any `%LOCALAPPDATA%` copy.
2. Each recipient extracts it, starts DSH Desktop once, and runs
   `install.cmd`. The script resolves their own `dsh.cmd`, DSH home and install
   directory; there are no machine-specific paths in the kit.
3. Each recipient adds the agent in SolidCraft once with the printed command.

Do not install this bundle into a non-desktop profile just to see it: the
desktop profile is the one DSH's Plugins page shows. For npm distribution,
remove `"private": true` from `bundle\package.json`, set a unique name and
version, and install with
`dsh plugin --profile desktop add <package-name>`.

## Uninstall or roll back

Use **Remove** in Plugins, or:

```powershell
dsh plugin --profile desktop remove dsh-solidcraft-bundle
```

The launcher then runs plain `dsh --profile acp`; remove the SolidCraft agent
entry and `<InstallDir>` if no longer needed. The pre-install manifests and
lockfiles are in `<InstallDir>\backup\` (`desktop-*`, `acp-*`); copy them back
over `%USERPROFILE%\.dsh\profiles\<profile>\` to roll back.

## Troubleshooting

- **The entry is missing from Plugins**: confirm DSH Desktop is running the
  desktop profile and that `dsh plugin --profile desktop list` shows
  `dsh-solidcraft-bundle`. Re-run the installer.
- **`no API key for provider route "deepseek-official"`**: the switch is
  disabled or removed, so the launcher did not pass the overlay. Enable it in
  Plugins and reconnect; check with
  `dsh --profile acp --dump-config`.
- **The SolidCraft tools are unavailable**: `solidcraft-cli.exe` is missing
  next to `solidcraft.exe`. Use the portable zip or MSI package, not the
  single-file exe.
- **Plugins says the bundle patch is empty and will not load**: update to kit
  0.2.2. It now inserts a no-op plugin row, so the market reports the switch as
  loaded; the row itself does nothing.
- **`dsh.cmd not found`**: pass `-DshCmd "C:\...\dsh.cmd"`.
- **PowerShell refuses install.ps1**: run `install.cmd` instead.

## Files

```text
dsh-solidcraft-kit\
  install.cmd             execution-policy wrapper
  install.ps1             installer
  README.md               this file
  bundle\                 the DSH bundle (visible switch + overlay)
    package.json
    index.js              no-op plugin loaded by the switch row
    cordis.patch.yml      inserts the one no-op switch row
    solidcraft.patch.yml  persona + account route for acp
    locale\{en,zh}.json
    docs\DETAIL.md
    icon.svg
    README.md
```
