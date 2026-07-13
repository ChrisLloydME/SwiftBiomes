# Seed finder discovery

Date: 2026-07-13

## Reference behavior

The local Qt reference lives under `.tmpBridge/cubiomes-viewer-trunk` and is read-only for this work.

- `src/mainwindow.ui` places Search beside the map and separates constraints from seed results.
- `src/formsearchcontrol.cpp` requires at least one condition before a search starts.
- The recommended general mode is `SEARCH_INC`: seeds are checked in numeric order, with an optional bounded range.
- Search progress includes the current seed and checked portion of the search space. The running action becomes an abort action.
- “Stop on results” is enabled by default. Results are de-duplicated, capped, sortable, and selecting one updates the map's active seed.
- `src/search.h` defines a large condition tree. Its point-biome condition uses included biome IDs at a coordinate and depends on the full 64-bit seed.

## Existing Swift data path

- `WorldSettings` already owns the selected Minecraft version and dimension.
- `BiomeQueryViewModel` and `MainSplitViewController` already apply a selected seed to the map and inspector.
- CubiomesCore 4.2.0 is pinned by `Package.resolved`. Its public `SeedSearchRequest`, `CubiomesQueryCondition.biomeAt`, progress callback, and cancellation token preserve deterministic request-order seed search semantics.

## Initial macOS scope

The first local version will implement the smallest complete Qt-compatible flow:

1. Define one point-biome condition using a target biome, X/Z coordinate, current version, and current dimension.
2. Search a user-bounded inclusive seed range in numeric order.
3. Stop after the requested result count (one by default), show progress, and allow cancellation.
4. Show unique results in discovery order. Selecting a result applies that seed to the existing map and inspector.

The implementation deliberately does not add Qt's 48-bit generators, seed-list/session files, compound/reference conditions, Lua, structure filters, or an unbounded full-seed-space search. Those are separate product and performance decisions, not implied by this first slice.

## UI boundary

The existing AppKit split-view, sidebar styling, system typography, and SF Symbols remain the visual source of truth. Seed search will use native controls and a focused sheet so the map remains primary, with explicit labels, keyboard-default actions, clear progress, and no new visual language.

## Repository verification surface

- The repository has no top-level README, AGENTS file, build script, or Swift package manifest.
- Xcode beta lists one shared scheme, `SwiftBiomes`, with app, unit-test, and UI-test targets.
- Minimum verification commands are `xcodebuild test` and `xcodebuild build` against the `SwiftBiomes` scheme using Xcode beta and a local derived-data path.
- `swift test` does not apply to the app repository because it has no `Package.swift`.
