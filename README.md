## Legendary Roamers v0.1.18 Alpha

### Changes

- Reworked custom visible legendary roaming to use one shared world actor.
- Fixed Ho-Oh not appearing while Overworld Encounters was enabled.
- Lugia, Ho-Oh and Celebi are now managed by the same visible roaming system.
- Multiple active custom legendary roamers can coexist.
- Optimized movement by caching encounter/grass cells when entering a map.
- Removed expensive per-frame encounter-cell rebuilding that caused major slowdown.

### Confirmed working

#### Lugia
- Visible overworld roaming with Overworld Encounters enabled.
- HP persistence between encounters.
- Status persistence between encounters.
- Relocation after an uncaught encounter.
- Catching permanently removes it from custom roaming state.

#### Ho-Oh
- Original encounter transitions into custom roaming after an uncaught battle.
- Visible overworld roaming with Overworld Encounters enabled.
- HP persistence between encounters, including returning at 1 HP after a KO.
- Relocation after an uncaught encounter.
- Catching permanently removes it from custom roaming state.

### Still to test

- Celebi's complete GS Ball / Ilex Forest encounter-to-roamer flow.

### Status

Legendary Roamers remains Alpha while Celebi receives its full gameplay test.
