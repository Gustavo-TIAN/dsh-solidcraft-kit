# dsh-solidcraft-bundle

The visible SolidCraft switch in DSH's **Plugins** page, installed in the
`desktop` profile.

- It inserts one no-op plugin row (`solidcraft-switch`) so the bundle is a
  real, loaded package in Plugins. The plugin does nothing; the Desktop
  assistant is unchanged.
- The kit's `dsh-acp.cmd` checks whether this bundle is enabled in the desktop
  profile; while it is, the launcher applies `solidcraft.patch.yml` to the
  `acp` profile (SolidCraft persona + DeepSeek account route).

Enable or disable it in Plugins to turn the SolidCraft integration on or off;
**Remove** uninstalls it. See `docs/DETAIL.md`.
