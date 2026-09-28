# PokéRecomp Legendary Roamers

A PokéRecomp mod that gives legendary Pokémon a second chance by turning uncaught legendary encounters into roaming Pokémon.

> **Status: Alpha / Work in Progress**

Legendary Roamers is currently under active development and testing. It is not yet intended as a stable release.

## Goal

The mod changes what happens when certain legendary Pokémon are encountered but not caught.

Instead of permanently losing the Pokémon after defeating it or leaving the battle, the legendary can become a roaming Pokémon.

The basic rule is:

**Caught = permanently removed.**  
**Not caught = remains available and can roam.**

## Current development

The current development version is based on PokéRecomp's mod API and is being tested primarily with Pokémon Crystal.

### Lugia

Lugia is currently the most extensively tested custom roamer.

Confirmed during testing:

- The original stationary Lugia encounter occurs normally.
- If Lugia is not caught, it can become a custom roamer.
- Lugia can be assigned to a route.
- Lugia can appear visibly in grass when Overworld Encounters are enabled.
- The overworld Lugia can move through valid encounter tiles.
- Walking into Lugia can start the battle automatically.
- Pressing A while facing Lugia can also start the battle.
- After an uncaught battle, Lugia can relocate to another route.
- Saved HP can be retained by the mod between encounters.

### Ho-Oh and Celebi

Support for Ho-Oh and Celebi is under development using the same custom roaming system.

Their intended behavior is:

- Their original encounter happens first.
- If caught, nothing changes.
- If the original encounter ends without a capture, roaming begins.

### Raikou, Entei and Suicune

Where possible, the mod intends to preserve PokéRecomp's native roaming mechanics for the legendary beasts.

The intended rule remains the same: only capturing a legendary should permanently remove it.

## Overworld roaming

Custom roamers can use PokéRecomp's world actor system so they can appear as visible Pokémon on their current route.

This allows custom legendary encounters to coexist with PokéRecomp's Overworld Encounters feature instead of relying exclusively on invisible random encounters.
