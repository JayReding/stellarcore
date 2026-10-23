# Stellar Core

A 4X space strategy game in development with Godot 4.7. This repository
currently contains the first playable slice: the **Stellar View**, the
full-screen **System View**, the **Technologies** tree, the **Newhome III
Shipyard**, the turn loop, and the first **fleet exploration** flow.

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
| Click a fleet row | Open the fleet actions dialog |
| Click an in-transit fleet marker | Open that fleet's actions dialog |
| Set Fleet Destination | Enter destination-selection mode |
| Click a star while choosing a destination | Open the course confirmation dialog |
| Confirm Destination | Send the fleet and close the dialog |
| `Esc` while choosing a destination | Cancel destination selection |
| Technologies button | Open the technology tree |
| Click a planet (surveyed) | Open that system in the full-screen System View |
| Shipyard button (Newhome) | Open the Newhome III shipyard |
| Produce Ship | Build one FTL Probe; creates a fleet if none is selected |
| Click a fleet (Shipyard) | Select it to reinforce it, or deselect it to create a new fleet |
| End Turn | Start or cancel the five-second countdown to advance the turn |
| `Esc` (Stellar View) | Deselect, cancel destination selection, or close a fleet dialog |
| `Esc` (System View, Technologies, or Shipyard) | Return to Stellar View |

## What is implemented

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
- A turn loop starting at **Turn 1**. The current turn is shown in the bottom-left
  HUD. **End Turn** in the bottom-right starts a five-second countdown; clicking
  the button again cancels it. When the countdown finishes, the turn advances,
  `TurnManager` emits `turn_advanced`, and every fleet in transit moves one leg
  of its course.
- A 3D star per system with an emissive surface, halo, and selection ring.
- Newhome is marked with a floating `NEWHOME` label and a home-system panel.
- Every system carries 2–6 procedurally generated planets ordered outward from
  its star. Classes are position-weighted: rocky and high-mineral worlds in the
  inner system, rare Earth-like worlds in the middle, dead worlds just beyond
  the habitable zone, and gas giants and ice worlds in the outer system.
- Planets are named after their star with Roman numerals (`SC-002 I`,
  `Newhome III`). Newhome always has four: **Newhome I** (Rocky), **Newhome II**
  (High-Mineral), **Newhome III** (Earth-like), and **Newhome IV** (Gas Giant).
- Only Newhome starts surveyed, so its planet list is the only one visible at
  first. The other systems already own their planets but report as unsurveyed.
  When an exploring fleet arrives, the system becomes surveyed and the arrival
  notice reports the number and types of its planets. The old **Scan** button is
  hidden now that probe arrival is the survey path.
- Clicking any planet in a surveyed system's **Planetary Survey** list opens the
  full-screen 3D **System View**. It shows the star at the center, compressed
  orbital rings, planet labels, and a back button (or `Esc`) to return to the
  Stellar View. The overlay uses 4x MSAA and adaptive 3D supersampling, with
  enlarged outlined labels for readability.
- The selected-system panel includes a **Fleet Command** section listing that
  system's fleets and their ships. Newhome starts with no fleets. Fleet rows are
  clickable and open the fleet actions dialog. Docked fleets stay in Fleet
  Command; only in-transit fleets get map markers, and a marker disappears as
  soon as the fleet arrives.
- The fleet actions dialog offers **Set Fleet Destination**, **Rename Fleet**,
  **Modify Fleet**, and **Delete Fleet** (red text). Only destination assignment
  is implemented in this slice; the other actions are present but disabled.
- **Set Fleet Destination** lets the player click a star. A confirmation dialog
  shows the destination, distance, fleet speed, and required turns before the
  course is accepted. `Back` returns to star selection, and `Esc` cancels.
- Fleets travel at the speed of their slowest ship. The FTL Probe currently
  moves **10 light years per turn**, so the number of turns is
  `ceil(distance / speed)` and the fleet moves on each turn advance.
- A sent fleet gets a moving map marker and a dashed course line from its origin
  to its destination. The marker shows only the fleet name, keeping the map
  uncluttered, and is removed when the fleet arrives.
- The arriving FTL Probe is consumed after it surveys the system. If it was the
  fleet's only ship, the fleet is deleted and its name becomes available for
  future production.
- The bottom-center status line reports destination prompts, departures, and
  arrivals. Arrival notices include the probe loss, the system's planet count and
  planet types, and the destination's panel immediately exposes its surveyed
  planet list.
- **Newhome III** is the only shipyard in the current slice. The panel's
  **Shipyard** button is enabled only for Newhome and opens a full-screen
  construction interface: hull types on the left, customization in the center,
  and the system's fleets on the right.
- The only hull type is the **FTL Probe**, a reconnaissance craft with no
  customization options. **Produce Ship** at the bottom center builds one probe.
  If no fleet is selected, a new fleet is created; otherwise the probe joins the
  selected fleet. Selecting a fleet again clears the selection.
- Fleets are named after their production system plus a Greek letter, beginning
  with **Newhome Alpha**, **Newhome Beta**, and continuing through **Newhome
  Omega**. Names are allocated from the galaxy's active fleets, so a deleted
  fleet releases its name. Once all 24 letters are used, a generation number is
  appended (**Newhome Alpha 2**, then **Newhome Omega 2**, and so on).
- Ship production is free for now. The interface notes that resource costs are
  not yet implemented.
- A **Technologies** button in the top bar opens a full-screen technology tree.
  **FTL Probes** is available from the start and appears as a rounded-square card
  marked "AVAILABLE BY DEFAULT" with no research requirement. The **0 RP**
  research-funds readout remains a placeholder for the future resource system.
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
  stellar_view.tscn        Main scene
  system_view.tscn         Full-screen system overlay
  tech_tree.tscn           Full-screen technology tree
  shipyard.tscn            Full-screen Newhome III shipyard
  star.tscn                Star visuals and pick collider
  ui/star_info_panel.tscn  Selected-system readout
  ui/fleet_dialog.tscn     Fleet actions and course confirmation popup
  ui/tech_node.tscn        Rounded-square technology card
scripts/
  stellar_view.gd          Spawning, input, selection, fleet courses, and turns
  system_view.gd           System View layout, lighting, and lifecycle
  tech_tree.gd             Technology data and tree overlay
  shipyard.gd              Hull selection, production, and fleet UI
  fleet_data.gd            Fleet position, speed, route, and ship composition
  fleet_marker.gd          Clickable in-transit fleet marker
  turn_manager.gd          Turn counter and cancellable end-turn countdown
  planet_texture_factory.gd  Procedural planet and cloud textures
  galaxy_generator.gd      Seeded star placement, Newhome, class mix
  galaxy.gd                Star list and light-year distance matrix
  galaxy_scale.gd          Light years <-> view world units
  star_data.gd             Spectra table, planets, fleets, shipyard data
  planet_data.gd           Planet classes, colors, and designations
  star.gd                  Per-star visuals
  camera_rig.gd            Orbit/tilt/zoom/focus camera
  ui/star_info_panel.gd    Panel population, clickable fleet rows, and fades
  ui/fleet_dialog.gd       Fleet action menu and course confirmation
  ui/tech_node.gd          Technology card population
shaders/
  star_surface.gdshader    Emissive star surface
  planet_atmosphere.gdshader  Rim haze for Earth-like and Dead Worlds
```

`StarData` is a `Resource` independent of the view, ready to carry ownership
and colony state as the turn-based layer is built. It also owns the system's
`PlanetData` list, `FleetData` list, shipyard planet reference, and `surveyed`
flag. `FleetData` stores a fleet's name, current system, light-year position,
ship composition, speed, and any active route (origin, destination, distance,
turns elapsed, and turns total) while formal ship models are still provisional.

## Verification

The headless galaxy check validates Newhome, the 100 ly bounds, class mix,
minimum separation, the distance matrix, and the planet rules (Newhome's fixed
four, 2–6 planets per procedural system, designations, and orbit order):

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

The shipyard check validates Newhome III ownership, the FTL Probe hull and its
empty customization panel, production with and without a selected fleet, Greek
fleet naming and overflow, Fleet Command refresh, and the disabled shipyard
state away from Newhome:

```bash
godot --headless --path . --script res://tests/verify_shipyard.gd
```

The exploration check validates the fleet action dialog and its disabled
management actions, destination selection and confirmation, travel-time math,
the dashed course line and moving marker, marker removal on arrival, turn-by-turn
movement, probe destruction, fleet deletion, fleet-name reuse, Fleet Command
refresh, and the arrival survey notice:

```bash
godot --headless --path . --script res://tests/verify_exploration.gd
```

The turn check validates the Turn 1 readout, the bottom-right End Turn button,
the five-second countdown and cancellation path, and the advance to later turns:

```bash
godot --headless --path . --script res://tests/verify_turns.gd
```

The technology tree check validates the top-bar button, the default-available
FTL Probes card, the research-funds placeholder, and the close paths:

```bash
godot --headless --path . --script res://tests/verify_tech_tree.gd
```

## Not yet implemented

Fleet management (rename, modify, and delete), research durations and spending,
the full scanning/discovery system, resource costs for ship production,
colonization, industry, combat, advanced hull customization, save/load, and the
Combat View.
