/**
 * The bundle's only plugin row. It does nothing: it exists so the bundle is a
 * real, loadable profile plugin that the plugin manager can report, instead of
 * an empty patch the market describes as "will not load".
 *
 * The SolidCraft persona and account route are in solidcraft.patch.yml, which
 * the kit's launcher applies to the acp profile while this bundle is enabled.
 */
export const name = 'solidcraft-switch'

export function apply() {}
