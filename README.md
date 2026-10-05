# Legendary Roamers

**Version:** 0.1.65 Alpha  
**PokéRecomp Mod API:** 59  
**Games:** Pokémon Gold, Silver and Crystal

Legendary Roamers gives supported one-time Legendary Pokémon another chance when their original encounter ends without a catch. Instead of being permanently lost, they can enter the mod's roaming system and remain available until they are caught.

> **Alpha status:** the main system is working, but Celebi and the three Legendary Beasts still need final end-to-end validation. See **Still to test** below.

## Current roster

- Raikou
- Entei
- Suicune
- Lugia
- Ho-Oh
- Celebi
- Mew
- Mewtwo
- Articuno
- Zapdos
- Moltres

## What is implemented

### Persistent custom roaming
Supported custom roamers preserve their individual battle data between encounters, including HP, DVs and status. A non-catch can relocate the same Pokémon instead of creating a fresh replacement. Catching it removes it permanently from the custom roaming system.

Visible custom roamers can appear on valid overworld encounter cells and can be interacted with for a tagged wild battle.

### Lugia and Ho-Oh
Their original encounters remain intact. If the encounter ends uncaught, the Legendary can enter the custom roaming system.

HP and status persistence have been tested. A KO currently returns the custom roamer with at least 1 HP.

### Mew
Mew appears after Red has been defeated, at Red's former position in Silver Cave Room 3.

- Level 50
- stationary and solid
- interact with A
- `MEW...` followed by its cry and battle
- caught: finished
- uncaught/KO: enters roaming

PokéRecomp 0.1.72 also repairs `beat_red` in older saves when they are loaded.

### Moltres
Moltres appears in Victory Road.

- Level 50
- stationary and solid
- A interaction
- cry followed by battle
- uncaught/KO: enters roaming

### Zapdos
Zapdos appears on Route 10 North outside the Power Plant.

- Level 50
- stationary and solid
- A interaction
- cry followed by battle
- unlocked through the custom Power Plant sequence
- uncaught/KO: enters roaming

The Power Plant includes a custom Officer NPC with Machine Part dialogue and a generator/power-surge sequence. The Zapdos unlock itself is working. The experimental full player-lock timing during the Officer's return walk is not considered finished and is not required for Zapdos to function.

### Articuno
Articuno appears in Ice Path B3F.

- Level 50
- stationary and solid
- A interaction
- cry followed by battle
- uncaught/KO: enters roaming

### Mewtwo
Mewtwo appears on Route 4 **only after Red has been defeated**.

- Level 70
- full custom introductory dialogue
- YES/NO challenge
- running from the battle keeps Mewtwo on Route 4 and gives rematch dialogue
- losing to Mewtwo keeps it on Route 4 and gives separate rematch dialogue
- defeating Mewtwo is the trigger that turns it into a custom roamer
- catching Mewtwo ends the chain

After being knocked out, Mewtwo roams **Kanto only**.

### Kanto-only Gen 1 roaming
The following Gen 1 Pokémon use a Kanto-only custom route pool:

- Mew
- Mewtwo
- Articuno
- Zapdos
- Moltres

Their locations are shown with readable route names in the mod status page instead of raw map coordinates.

### Menu structure
PokéRecomp 0.1.72's `menu_path` support is used:

`MODS > Community Mods > SIRsparky Mods > Legendary Roamers`

Mods using the same category path can share the SIRsparky Mods submenu.

## Tested and confirmed

The following have been tested successfully during development:

- Lugia custom roaming, including HP/status persistence
- Ho-Oh custom roaming, including KO recovery at 1 HP
- Mew story encounter and transition into roaming
- Moltres encounter and roaming transition
- Zapdos placement, Power Plant unlock and roaming transition
- Articuno encounter and roaming transition
- Mewtwo Route 4 placement
- Mewtwo introductory dialogue and YES/NO flow
- Mewtwo RUN/rematch flow
- Mewtwo KO -> custom roamer transition
- Mewtwo and the other Gen 1 custom roamers restricted to Kanto
- readable Kanto route names
- new PokéRecomp 0.1.72 menu hierarchy

## Still to test

These are intentionally listed as **not yet fully validated**, rather than claimed as finished:

### Celebi
Test the complete chain:

1. original Celebi encounter
2. end the encounter without catching it / KO it
3. confirm it becomes a Johto custom roamer
4. confirm overworld visibility and interaction
5. confirm subsequent relocation
6. catch it and confirm permanent removal

### Raikou and Entei
Their normal cartridge roaming should remain the first phase. The important remaining test is what happens after either native roamer is knocked out.

Expected final behaviour:

1. native Raikou/Entei roams normally
2. it is knocked out
3. the native roamer disappears
4. Legendary Roamers takes it over as a custom **Johto** roamer
5. there must not be a duplicate native + custom roamer
6. it remains available until caught

This takeover still needs to be proven in-game and may require an additional fix if the current battle events do not expose the native KO as expected.

### Suicune
Crystal's scripted Suicune path has special handling. Its complete KO/non-catch -> continued roaming behaviour still needs final in-game validation.

Gold and Silver also need validation against their native Suicune behaviour.

## Planned work

After the remaining Pokémon are validated, the next planned roaming-system upgrade is:

- flee/non-catch: immediately relocate to another route
- while active: relocate again after approximately 1 minute
- KO: disappear for a 10-minute cooldown
- KO recovery starts at 1 HP
- every 5 minutes: recover +25 HP, capped at max HP
- after 10 minutes: reappear on a new route
- status conditions such as SLP, PAR and PSN remain persistent
- timers/recovery should be per roamer and survive save/load

These timer and regeneration rules are **not implemented in v0.1.65**.

## Notes

- This is still an Alpha/work-in-progress release.
- The original Legendary encounter is preserved wherever possible; the mod is intended as a second-chance system, not a replacement for the normal encounter.
- Gen 1 custom roamers are deliberately restricted to Kanto.
- Gen 2 custom roamers are intended to remain in Johto.
- The current stable code path is based on the proven v0.1.63 Mewtwo implementation, with the Kanto-only routing and PokéRecomp 0.1.72 menu path added on top.

## Credits

Created by **SIRsparky989** for **PokéRecomp**.
