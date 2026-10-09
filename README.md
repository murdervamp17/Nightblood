# Nightblood: Containment Break — sandbox prototype

An original 2D side-on pixel-art vampire horror sandbox made with Godot 4.3. The project is intentionally a small playable prototype, not a finished game. Its presentation takes broad inspiration from side-scrolling pixel horror games; character art, setting, and code here are original placeholder work.

## Play on desktop
1. Install Godot 4.3.x (standard build).
2. Open this folder as a project in Godot.
3. Press F6 or F5 to run.

### Controls
- **A / D**: move left/right
- **Space**: telekinesis (toggle a nearby crate between held and thrown)
- **F**: feed on a nearby living test subject to gain evolution XP
- **Shift**: vampiric dash (unlocks through feeding/evolution)
- **E**: spend XP to upgrade powers
- **F1**: debug-unlock flight for sandbox testing
- **Up / Down**: fly up/down after flight unlock (desktop)

Touch buttons are drawn for Android testing. On mobile, tap **FLY** to unlock flight, then hold the button while moving. Touch controls are prototype-level and may need tuning on specific screen sizes.

## Build Android APK with GitHub Actions
1. Create a new GitHub repository and upload the contents of this folder (keep `.github/workflows/android-apk.yml`).
2. In GitHub, open **Actions** and enable workflows if prompted.
3. Push to the `main` branch or manually run **Build Android APK** from Actions.
4. Open the successful workflow run and download the `nightblood-debug-apk` artifact.

The workflow uses the Godot 4.3 export container and Android export templates. The first build can take several minutes. If GitHub reports an Android SDK/template configuration issue, see the workflow log; CI images and export tooling can change over time.

## Current prototype features
- Low-resolution side-on industrial horror environment with nearest-neighbour/pixelated presentation
- Player silhouette becomes more monstrous at evolution milestones
- Telekinesis on nearby crates
- Feeding on test subjects for XP and regeneration-style feedback
- Flight unlocks through progression (F1 debug unlock for desktop testing)
- Vampiric dash with red afterimage trail
- Upgrade button and XP/evolution HUD
- Touch UI for testing on Android

## Next development steps
- Replace placeholder block sprites with original sprite sheets and frame animations
- Add health, damage, enemy AI, sound design, save data and proper level geometry
- Improve touch controls and test on real devices
- Add proper flight and dash unlock thresholds, upgrade choices, and environment transformation
