# MacZones

En macOS-udgave af FancyZones fra PowerToys: definer zoner på dine skærme og snap vinduer ind i dem.

## Funktioner

- **Træk og slip:** Hold ⇧ Shift nede mens du trækker et vindue. Zonerne vises, og vinduet snapper til den zone du slipper i.
- **Flere zoner:** Hold også ⌃ Control nede for at strække vinduet over flere zoner.
- **Tastatur:** ⌃⌥← / ⌃⌥→ flytter det aktive vindue til forrige/næste zone (også på tværs af skærme). ⌃⌥1–9 flytter det til en bestemt zone.
- **Layouts pr. skærm:** Vælg layout i menulinjen eller i editoren.
- **Layout-editor:** Skabeloner (kolonner, prioritet, gitter …) samt dine egne layouts. Du kan trække zoner rundt, ændre størrelse, dele dem lodret/vandret og slette dem.
- Justerbar afstand mellem zonerne.

## Installér

Kræver macOS 14 (Sonoma) eller nyere og Xcode 16 eller nyere (installeres fra App Store).

### Med Claude Code

```bash
git clone https://github.com/kasperlegarth/MacZones.git
cd MacZones
claude
```

Skriv så **"Installér MacZones"**. Claude tjekker forudsætningerne, bygger og installerer appen og guider dig igennem tilladelsen til
Tilgængelighed. Instruktionerne til Claude ligger i [`CLAUDE.md`](CLAUDE.md).

### Manuelt

```bash
git clone https://github.com/kasperlegarth/MacZones.git
cd MacZones
./scripts/create-signing-cert.sh   # kun første gang
./scripts/install.sh               # bygger og installerer i /Applications
```

### Opdatering

```bash
git pull
./scripts/install.sh
```

Tilladelser og indstillinger bevares.

MacZones starter automatisk ved login, første gang den kører fra `/Applications`. Det kan slås fra i menuen eller under Indstillinger.

### Andre scripts

| Script | Gør |
| --- | --- |
| `scripts/build-app.sh` | Bygger `build/MacZones.app` uden at installere |
| `scripts/make-dmg.sh` | Laver `build/MacZones-<version>.dmg` til deling |
| `scripts/make-icon.sh` | Genererer `Resources/AppIcon.icns` fra `scripts/make-icon.swift` |

### Tilladelse

Første gang skal appen have adgang under **Systemindstillinger → Anonymitet og sikkerhed → Tilgængelighed**.
Uden den kan den ikke flytte vinduer, og der sker ingenting, når du trækker.

> `create-signing-cert.sh` laver et lokalt, selvsigneret certifikat ("MacZones Dev") i din login-nøglering. Uden det bliver appen
> ad-hoc-signeret, og så "glemmer" macOS tilladelsen ved hver build, selvom kontakten stadig står tændt.
> Hvis det er sket, så kør `tccutil reset Accessibility com.kasperlegarth.MacZones` og giv tilladelsen igen.

Indstillinger gemmes i `~/Library/Application Support/MacZones/config.json`.

## Afinstallér

```bash
pkill -x MacZones; rm -rf /Applications/MacZones.app
tccutil reset Accessibility com.kasperlegarth.MacZones
rm -rf ~/Library/Application\ Support/MacZones           # valgfrit: slet layouts og indstillinger
security delete-certificate -c "MacZones Dev"            # valgfrit: slet signeringscertifikatet
```

Fjern også MacZones under **Systemindstillinger → Generelt → Login-emner**, hvis den stadig står der.

## Opbygning

| Fil | Ansvar |
| --- | --- |
| `DragMonitor.swift` | Globale mus-events; finder ud af hvornår et vindue bliver trukket |
| `ZoneEngine.swift` | Finder zonen under markøren, flytter vinduer, tastaturnavigation |
| `Overlay.swift` | Det gennemsigtige overlay der viser zonerne |
| `Accessibility.swift` | Flytter/ændrer størrelse på vinduer via Accessibility API |
| `LayoutStore.swift` / `Models.swift` | Layouts, skabeloner og gemte indstillinger |
| `EditorView.swift` | SwiftUI-editoren |
| `HotKeys.swift` | Globale tastaturgenveje |
| `LaunchAtLogin.swift` | Start ved login (`SMAppService`) |
