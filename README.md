# Stellar Core

A 4X space strategy game in development with Godot 4.7. This repository
currently contains the first playable slice: the **title screen**, the
**Stellar View**, the
full-screen **System View** with a structure and economy sidebar, the
**Technologies** tree, the **Newhome III Shipyard**, per-system **resource
stockpiles**, planet-attached **structures**, the turn loop, and the first
**fleet exploration** flow.

## Running

Open `project.godot` in Godot 4.7 or newer and press **F5**. The first editor
open also imports the project and registers its script classes.

From a terminal:

```bash
# One-time import when opening a fresh checkout from the CLI.
godot --headless --editor --path . --quit

# Run the game.
godot --path .
```

## Controls

| Input | Action |
| --- | --- |
| Left-drag | Rotate around the galaxy and tilt vertically |
| Mouse wheel | Zoom in/out |
| Click a star | Select it and open the system panel |
| Double-click a star | Focus the camera on it |
| Click a fleet row | Open the fleet orders popup |
| Click an in-transit fleet marker | Open that fleet's orders popup |
| Right-click a fleet or marker | Open the fleet orders popup at the cursor |
| Click away from the orders popup | Dismiss it |
| Set Fleet Destination | Enter destination-selection mode |
| Click a star while choosing a destination | Open the course confirmation dialog |
| Confirm Destination | Send the fleet and close the dialog |
| `Esc` while choosing a destination | Cancel destination selection |
| Technologies button | Open the technology tree |
| Scroll in the technology tree | Pan around the category grid |
| Click a planet (surveyed) | Open that system in the full-screen System View |
| Click a planet (System View) | Inspect that planet's structures and resource flow |
| Shipyard button (Newhome) | Open the Newhome III shipyard |
| Produce Ship | Queue one of the selected hull (cost is spent up front) |
| Cancel (shipyard queue) | Cancel a queued build and refund unused resources |
| Drag a ship chip | Move it onto another fleet in the shipyard |
| + New Fleet | Create an empty fleet to drag ships into |
| End Turn | Start or cancel the five-second countdown to advance the turn |
| `Esc` (Stellar View) | Deselect, cancel destination selection, or close the fleet orders popup |
| `Esc` (System View, Technologies, or Shipyard) | Return to Stellar View |

## What is implemented

- A **title screen** using the `StellarCoreTitle.svg` art with a five-item
  menu: **New Game** starts a fresh game, **Quit to Desktop** exits,
  **Credits** opens a credits panel, and **Load Saved Game** and **Options**
  are greyed out until later slices. The looping `Mirage.mp3` title theme
  plays until a new game starts, when the looping `Mesmerizing Galaxy Loop.mp3`
  gameplay track takes over at a lower volume.

- A 100-light-year-diameter play area. Star positions and all travel distances are
  stored in light years, with stars within ±4 ly of the galactic plane.
- 25 procedurally placed stars plus **Newhome**, the player's fixed G2V home
  system at the center of the map.
- A precomputed light-year distance matrix for every pair of systems, used by
  the system panel and ready for travel-range rules.
- Real spectral classes **O, B, A, F, G, K** with class-specific colors, sizes,
  temperatures, and descriptions.
- Gameplay-weighted class distribution (1 O, 2 B, 4 A, 5 F, 6 G, 7 K among the
  procedural stars; Newhome adds one more G).
- Seeded generation; the seed is shown in the HUD. Set `galaxy_seed` on the
  `StellarView` root node to reproduce a specific map.
- Resources are stockpiled per star system. **Newhome** begins with **200
  Titanium**, **200 Helium 3**, and **50 Antimatter**; every other system starts
  empty. **Composites** and **Meta-Matter** are tracked at zero but remain hidden
  until they are revealed through progression.
- Selecting a system shows its local resource list in the **Selected System**
  panel. The per-system stockpiles are the foundation for the planned cargo
  transport mechanic.
- **Research Data** is galaxy-wide. Its readout appears in the top-left HUD and
  in the technology tree, beginning at **0 RD**. Colonies produce Research Data
  each turn.
- A turn loop starting at **Turn 1**. The current turn is shown in the bottom-left
  HUD. **End Turn** in the bottom-right starts a five-second countdown; clicking
  the button again cancels it. When the countdown finishes, the turn advances,
  `TurnManager` emits `turn_advanced`, every fleet in transit moves one leg of
  its course, and structures apply their output and upkeep.
- A 3D star per system with an emissive surface, halo, and selection ring. Stars
  render at 80% of their original radius so the map stays readable.
- Newhome is marked with a floating `NEWHOME` label and a home-system panel.
- Explored systems show their star name beneath the star. The name appears as
  soon as a probe surveys the system and stays visible in the Stellar View;
  Newhome keeps its separate gold `NEWHOME` label.
- Every system carries 2–6 procedurally generated planets ordered outward from
  its star. Classes are position-weighted: rocky and high-mineral worlds in the
  inner system, rare Earth-like worlds in the middle, dead worlds just beyond
  the habitable zone, and gas giants and ice worlds in the outer system.
- Planets are named after their star with Roman numerals (`SC-002 I`,
  `Newhome III`). Newhome always has four: **Newhome I** (Rocky), **Newhome II**
  (High-Mineral), **Newhome III** (Earth-like), and **Newhome IV** (Gas Giant).
- Structures are attached to planets and are either **surface** or **orbital**.
  Newhome starts with four:
  - **Newhome II** (orbit): **Ore Processing Station**, producing 25 Titanium and
    consuming 2 Helium 3 per turn.
  - **Newhome III** (surface): **Colony**, producing 10 Titanium, 2 Helium 3, and
    5 Research Data per turn. A Colony permits construction in its system.
  - **Newhome III** (orbit): **Shipyard**, consuming 2 Helium 3 per turn and
    enabling ship production.
  - **Newhome IV** (orbit): **Helium3 Station**, producing 20 Helium 3 and 1
    Antimatter per turn.
- Those base figures give Newhome a net **+35 Titanium**, **+18 Helium 3**,
  **+1 Antimatter**, and **+5 Research Data** per turn. Production is
  intentionally flat for now;
  planetary richness will scale it later.
- Only Newhome starts surveyed, so its planet list is the only one visible at
  first. The other systems already own their planets but report as unsurveyed.
  When an exploring fleet arrives, the system becomes surveyed, its name appears
  on the map, and the arrival notice reports the number and types of its planets.
  The old **Scan** button is hidden now that probe arrival is the survey path.
- Clicking any planet in a surveyed system's **Planetary Survey** list opens the
  full-screen 3D **System View**. It shows the star system centered in the space
  left of the sidebar, compressed orbital rings, planet labels, and a back button
  (or `Esc`) to return to the Stellar View. The overlay uses 4x MSAA and adaptive
  3D supersampling, with enlarged outlined labels for readability.
- The System View's right-hand sidebar shows the system's current resource
  balances and per-turn change for every visible local resource, with positive
  changes in green and negative changes in red. Galaxy-wide Research Data is
  shown separately. The sidebar opens with a large **SYSTEM OVERVIEW** heading,
  followed by the resource lists and the structures built in the system, grouped
  by planet. Clicking a planet (or a structure row) opens a separate
  **Planet Detail** sidebar on top of the overview, showing every structure on
  that planet and each individual resource contribution or upkeep line, plus a
  **BUILD STRUCTURE** button and a close button (`Esc` also dismisses it,
  topmost layer first).
- **BUILD STRUCTURE** opens a centered popup with the construction options for
  the selected planet. Construction is available only in systems with a
  **Colony** and offers every unlocked non-Colony structure with its
  production/upkeep summary plus its construction cost and build time. Every
  player-built structure except the **Shipyard** costs **200 Titanium** from
  the system's local stockpile, spent up front, and takes **3 turns** to
  complete; the Shipyard is free and instant. Locked structures
  appear greyed out as **REQUIRES RESEARCH** until their technology completes
  (for example, the **Antimatter Refinery** needs **Antimatter Refining**); only
  one Shipyard per system is allowed, and a structure already on the planet
  shows **ALREADY PRESENT**. Unaffordable rows are disabled with a red
  shortfall amount. Only one construction project runs per star system at a
  time; the other rows read **IN PROGRESS** until it finishes. The popup stays
  open with a confirmation message, and the sidebars, flows, summaries, and
  per-turn economy pick finished structures up the turn they complete. `Esc`
  closes the popup first, then the Planet Detail sidebar, then the System View
  itself.
- While anything is under construction, a **CONSTRUCTION** panel on the
  Stellar View lists each project with its system, structure, and turns left.
  The status line announces each completion.
- The selected-system panel includes a **Fleet Command** section listing that
  system's fleets and their ships. Newhome starts with no fleets. Clicking or
  right-clicking a fleet (in Fleet Command or on its map marker) opens a small
  orders popup at the cursor instead of a modal screen. Clicking anywhere else
  or pressing `Esc` dismisses it. Docked fleets stay in Fleet Command; only
  in-transit fleets get map markers, and a marker disappears as soon as the
  fleet arrives.
- The fleet orders popup offers **Set Fleet Destination**, **Rename Fleet**,
  **Modify Fleet**, and **Delete Fleet** (red text). Only destination assignment
  is implemented in this slice; the other actions are present but disabled.
- **Set Fleet Destination** lets the player click a star. A confirmation dialog
  shows the destination, distance, fleet speed, and required turns before the
  course is accepted. `Back` returns to star selection, and `Esc` cancels.
- Fleets travel at the speed of their slowest ship. The FTL Probe moves
  **10 light years per turn** while the **Colony Ship** manages only **5**, so
  the number of turns is `ceil(distance / speed)` and the fleet moves on each
  turn advance.
- A sent fleet gets a moving map marker and a dashed course line from the marker
  to its destination, shortening as the fleet travels. Each cluster of
  coincident markers gets one small stacked name label at its side, listing
  its in-transit fleets one per line so multiple departures never collide; the
  stack travels with its markers. A marker disappears as soon as its fleet
  arrives.
- The arriving FTL Probe is consumed after it surveys the system. If it was the
  fleet's only ship, the fleet is deleted and its name becomes available for
  future production.
- The bottom-center status line reports destination prompts, departures, and
  arrivals. Arrival notices include the probe loss, the system's planet count and
  planet types, and the destination's panel immediately exposes its surveyed
  planet list.
- The **Shipyard structure** in orbit of **Newhome III** is the only shipyard in
  the current slice and consumes 2 Helium 3 per turn. The panel's **Shipyard**
  button is enabled only for Newhome and opens a full-screen construction
  interface: hull types on the left, customization in the center, and the
  system's fleets on the right.
- The only default hull type is the **FTL Probe**, a reconnaissance craft with
  no customization options. It costs **25 Titanium** and **10 Antimatter** and
  takes **0.25 turns** to build (four per turn). Researching **Colony Ships**
  unlocks a second hull, the **Colony Ship** (**500 Titanium** and
  **1 Antimatter**, **3 turns** to build), which appears in the shipyard hull
  list once unlocked. The 1 Antimatter is a placeholder until the ship
  refueling mechanic lands, and future technologies may influence build times.
- **Produce Ship** at the bottom center queues one of the selected hull and
  spends its cost up front from the system's local stockpile. Each turn applies
  one turn of work to the queue, oldest hull first, so queued probes finish
  four at a time. Completed ships join the newest stationed fleet, or a new
  fleet when none is stationed.
- Queued builds show their progress (**Turn 1 of 3** style) with a **Cancel**
  button. Cancelling refunds unused resources pro-rata, except Antimatter,
  which is always fully refunded as fuel is loaded last.
- Fleet rows list each ship as a draggable chip. Dragging a ship onto another
  fleet moves it there; a fleet emptied this way is removed and its name
  becomes available again. The **+ New Fleet** button creates an empty fleet
  to drag ships into.
- Fleets are named after their production system plus a Greek letter, beginning
  with **Newhome Alpha**, **Newhome Beta**, and continuing through **Newhome
  Omega**. Names are allocated from the galaxy's active fleets, so a deleted
  fleet releases its name. Once all 24 letters are used, a generation number is
  appended (**Newhome Alpha 2**, then **Newhome Omega 2**, and so on).
- The shipyard's cost readout shows each required resource and turns missing
  resources red with the shortfall amount. **Produce Ship** is disabled and
  greyed out when the local stockpile cannot cover the full cost, and the status
  line explains what is missing.
- A **Technologies** button in the top bar opens a full-screen technology tree.
  The tree is a scrolling grid: one column per category (**Propulsion**,
  **Exploration**, **Industrial**, **Military**, **Advanced Technology**) with
  tier labels running down the side, and new technologies appear under their
  category column as the tree grows. Tier 1 contains **Propulsion**
  (**FTL Probes**), **Exploration** (**Colony Ships**, 100 RD, 5 turns),
  **Industrial** (**Ore Processing**), and **Military** (**Destroyer Hull
  Plan**, 50 RD, 3 turns): a small, light military platform using standard
  missiles for long range combat. Tier 2 contains **Industrial**
  (**Antimatter Refining**, 50 RD, 3 turns). Each card shows its icon, name,
  larger description, and cost and time together on one yellow line; researched
  technologies hide that line and simply read **AVAILABLE** in green.
- Clicking a researchable technology while no project is active opens a
  confirmation dialog that restates the technology, its Research Data cost, and
  its research time. **Begin Research** spends the Research Data up front; it is
  disabled with a red warning if the player cannot afford the project.
- While research is active, the HUD Research Data panel shows the project name,
  turns remaining, and a progress bar. Research advances one turn at a time with
  **End Turn**. Completing a technology marks its card **UNLOCKED** and applies
  its unlocked ships or structures. **Antimatter Refining** unlocks the
  **Antimatter Refinery** orbital structure, **Colony Ships** unlocks the
  **Colony Ship** hull in the shipyard, and **Destroyer Hull Plan** unlocks
  nothing yet — it is the first step toward combat hulls.
- A Colony Ship that reaches a system without a Colony queues a decision and
  opens a **Found a Colony** popup listing the system's planets. Picking one
  founds the Colony there and consumes the ship (disbanding an emptied fleet);
  closing the popup postpones the choice, which returns when the fleet is
  selected again — the ship stays aboard until a planet is chosen. Settled
  systems never queue a decision and keep the ship. Enemy-held systems will
  refuse colonies once hostile fleets exist.
- Procedural planets in the System View with star-driven light and dark sides.
  Each class has its own deterministic, cached surface texture:
  - **Rocky**: brown and gray terrain with craters.
  - **High-Mineral**: gray/white stone with rust-colored mineral patches and
    craters.
  - **Dead World**: rusty Mars-like terrain, sparse craters, and a faint
    atmospheric haze.
  - **Earth-like**: oceans, continents, greenery, polar ice, a separate cloud
    layer, and a blue atmospheric rim.
  - **Gas Giant**: Jupiter, Neptune, or Uranus palette, banded clouds, and
    storm spots.
  - **Ice World**: pale, nearly featureless ice with small brown stains and a
    few craters.
- Mouse picking, hover cursor, right-side system readout, and smooth camera
  focus.
- A faint polar reference grid extending to the 50 ly map boundary.

## Project layout

```
scenes/
  title_screen.tscn        Title screen (main scene)
  stellar_view.tscn        Stellar View galaxy map
  system_view.tscn         Full-screen system overlay
  tech_tree.tscn           Full-screen technology tree
  shipyard.tscn            Full-screen Newhome III shipyard
  star.tscn                Star visuals and pick collider
  ui/star_info_panel.tscn  Selected-system readout
  ui/fleet_menu.tscn     Cursor-anchored fleet orders popup
  ui/fleet_dialog.tscn     Course confirmation popup
  ui/tech_node.tscn        Rounded-square technology card
scripts/
  stellar_view.gd          Spawning, input, selection, fleets, turns, economy
  system_view.gd           System View layout, planet picking, economy sidebar
  tech_tree.gd             Technology data and tree overlay
  shipyard.gd              Hull selection, production, and fleet UI
  fleet_data.gd            Fleet position, speed, route, and ship composition
  fleet_marker.gd          Clickable in-transit fleet marker
  turn_manager.gd          Turn counter and cancellable end-turn countdown
  resource_stockpile.gd    Per-system resource definitions and balances
  structure_data.gd        Structure definitions, output, upkeep, and location
  planet_texture_factory.gd  Procedural planet and cloud textures
  galaxy_generator.gd      Seeded star placement, Newhome, starting structures
  galaxy.gd                Star list and light-year distance matrix
  galaxy_scale.gd          Light years <-> view world units
  star_data.gd             Spectra, planets, fleets, resources, structures
  planet_data.gd           Planet classes, colors, designations, structures
  star.gd                  Per-star visuals
  camera_rig.gd            Orbit/tilt/zoom/focus camera
  ui/star_info_panel.gd    Panel population, clickable fleet rows, and fades
  ui/fleet_menu.gd       Fleet orders popup at the cursor
  ui/fleet_dialog.gd       Course confirmation popup
  ui/tech_node.gd          Technology card population
  title_screen.gd          Title menu, theme music, and credits
shaders/
  star_surface.gdshader    Emissive star surface
  planet_atmosphere.gdshader  Rim haze for Earth-like and Dead Worlds
```

`StarData` is a `Resource` independent of the view, ready to carry ownership
and additional turn-based state. It also owns the system's
`PlanetData` list, `FleetData` list, local `ResourceStockpile`, shipyard planet
reference, and `surveyed` flag. It aggregates each planet's structures and their
net local-resource and Research Data flows.
`PlanetData` owns its `StructureData` list. Each structure declares whether it is
on the surface or in orbit and carries base production, upkeep, and Research Data
values. `StarData` exposes helpers for colony construction permission, shipyard
presence, system resource flow, and Research Data flow.
`FleetData` stores a fleet's name, current system, light-year position, ship
composition, speed, and any active route (origin, destination, distance, turns
elapsed, and turns total) while formal ship models are still provisional.
`ResourceStockpile` holds one system's raw-resource balances, resource metadata,
and the add/spend/transfer helpers used by the system panel, shipyard, and future
production costs. `StellarView` applies structure output and upkeep on
`turn_advanced`; the System View reads the same data for its sidebar. Research
Data is stored separately on `StellarView` because it is galaxy-wide, along with
the global hidden-resource reveal state.

## Verification

The headless title screen check validates the background art, the looping
title theme, the five menu entries in order, the disabled Load/Options
entries, the Credits popup, the New Game transition into the Stellar View,
and the handoff to the looping lower-volume gameplay track:

```bash
godot --headless --path . --script res://tests/verify_title_screen.gd
```

The headless galaxy check validates Newhome, the 100 ly bounds, class mix,
minimum separation, the distance matrix, the reduced star visual scale, and the
planet rules (Newhome's fixed four, 2–6 planets per procedural system,
designations, and orbit order):

```bash
godot --headless --path . --script res://tests/verify_galaxy.gd
```

The planet visual check generates an albedo texture for every planet class and
verifies the Earth cloud layer:

```bash
godot --headless --path . --script res://tests/verify_planet_visuals.gd
```

The System View check validates the clickable planet entry points, the
surveyed/unsurveyed panel state, Fleet Command's empty state, Shipyard
availability, and the overlay close paths:

```bash
godot --headless --path . --script res://tests/verify_system_view.gd
```

The structure check validates the four starting Newhome structures and their
surface/orbit locations, base production and upkeep, Colony construction
permission, Shipyard availability, per-planet flow entries, per-turn system and
galaxy-wide economy application, sidebar balances, larger overview text,
left-of-sidebar system centering, green/red changes, planet click targets, the
system structure list, the Planet Detail overlay sidebar, Planet Detail
output/upkeep rows, and the construction popup (Build button flow, cost/time
display, Colony and research-unlock gating, affordability shortfalls,
duplicate/Shipyard rules, one project per system, queued builds with upfront
spending, turn-by-turn progress on the Stellar View HUD, completion effects,
and Esc layering):

```bash
godot --headless --path . --script res://tests/verify_structures.gd
```

The shipyard check validates Newhome III ownership, the FTL Probe hull, its
build time and empty customization panel, the 25 Titanium/10 Antimatter cost
and upfront deduction, queued multi-turn builds with per-turn progress,
batched sub-turn completions, cancellation with pro-rated Titanium and full
Antimatter refunds, insufficient-resource button gating and red cost readout,
the newest-fleet default for completions, the New Fleet button, drag-and-drop
ship moves between fleets, empty-fleet removal with name reuse, Greek fleet
naming and overflow, the Colony Ship unlock, its 500 Titanium/1 Antimatter
cost, 3-turn build time, and 5 ly/turn speed, Fleet Command refresh, and the
disabled shipyard state away from Newhome:

```bash
godot --headless --path . --script res://tests/verify_shipyard.gd
```

The exploration check validates the fleet orders popup and its click-away,
right-click, and Escape dismissal, the disabled management actions, destination
selection and confirmation, travel-time math,
the dashed course line and moving marker, the stacked per-star departure labels,
marker removal on arrival, turn-by-turn
movement, probe destruction, fleet deletion, fleet-name reuse, Fleet Command
refresh, the explored-system name labels, and the arrival survey notice:

```bash
godot --headless --path . --script res://tests/verify_exploration.gd
```

The turn check validates the Turn 1 readout, the bottom-right End Turn button,
the five-second countdown and cancellation path, and the advance to later turns:

```bash
godot --headless --path . --script res://tests/verify_turns.gd
```

The resource check validates Newhome's starting balances, empty non-home
systems, independent per-system stockpiles, the selected-system resource list,
hidden-resource reveal state, transfer/spending helpers, galaxy-wide Research
Data, and the shipyard's local Titanium readout:

```bash
godot --headless --path . --script res://tests/verify_resources.gd
```

The technology tree check validates the top-bar button, the category-column
grid with tier gutters, the placement and cards of the Propulsion, Exploration,
Industrial, and Military sections across Tier 1 and Tier 2 (including the new
Destroyer Hull Plan), card contents and yellow cost/time readout, the green
AVAILABLE state, the Research Data readout, scrolling, and the close paths:

```bash
godot --headless --path . --script res://tests/verify_tech_tree.gd
```

The research check validates the confirmation dialog and its cost/time readout,
affordability gating, Research Data spending, turn-by-turn progress, the HUD
project and turns-remaining display, completion state, and the Antimatter
Refinery and Colony Ship unlocks:

```bash
godot --headless --path . --script res://tests/verify_research.gd
```

The colonization check validates Colony Ship speed and voyage pricing, the
planet-picker popup with one row per planet, founding on the chosen planet,
ship consumption and fleet disbanding, postponing and reopening the choice,
survey and Colony production afterwards, and keeping the ship when a Colony
already exists:

```bash
godot --headless --path . --script res://tests/verify_colonization.gd
```

## Not yet implemented

Fleet management dialog actions (rename, modify, delete), cargo transport between systems,
resource extraction from surveyed planets, planetary richness scaling,
structure input-shortage rules, the full scanning/discovery
system, enemy-held systems, ship refueling, combat, advanced hull
customization, save/load, and the Combat View.
