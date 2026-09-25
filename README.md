# ClassPing

A small World of Warcraft addon that shows your FPS and latency in your class color.

- One movable line: `53 fps   42 ms`, numbers in class color, red when under 30 fps or over 250 ms.
- Hover it for a performance tooltip: framerate now and over the last 60 s, home and world
  latency, bandwidth, addon memory (top 5), Lua memory, and addon CPU when `scriptProfile` is on.
- Right-click the line or type `/cp` for a settings window. The same settings are also under
  Escape > Options > AddOns > ClassPing.
- Font picker with bundled fonts, the game fonts, and any LibSharedMedia fonts other addons provide.

## Slash commands

```
/cp                open the settings window
/cp lock|unlock    lock, or unlock so you can drag the line
/cp reset          put the line back at the default spot
/cp size N         font size 8-24
/cp font [name]    list fonts, or switch to one
/cp home           toggle home/world latency
/cp show|hide      show or hide the line
```

## Install

Copy the `ClassPing` folder into `World of Warcraft/<flavor>/Interface/AddOns/` and restart the client
(new addon folders and new font files are only picked up at startup).

## Bundled fonts

| File | Licence |
| --- | --- |
| Expressway_Free.ttf | Free for personal use (Typodermic) |
| PTSansNarrow-Bold.ttf | SIL Open Font License |
| LiberationSans-Regular.ttf | SIL Open Font License |
| FiraMono-Regular.ttf | SIL Open Font License |
| DejaVuSansMono.ttf | Bitstream Vera / DejaVu licence |
| Prototype.ttf | Freeware (Mitchell Lee / Fonts2u) |
