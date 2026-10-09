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

Download the latest zip from [Releases](https://github.com/FerMPY/ClassPing/releases), extract it into
`World of Warcraft/<flavor>/Interface/AddOns/` so you end up with `AddOns/ClassPing/ClassPing.toc`, and restart
the client (new addon folders and new font files are only picked up at startup).

Works on Retail, Classic Era, Season of Discovery, Mists Classic and the other Classic flavors listed in the `.toc`.

## Releasing

Push a tag like `v2.6` and the [release workflow](.github/workflows/release.yml) packages the addon with the
BigWigs packager and attaches the zip to a GitHub release. Bump `## Version` in `ClassPing.toc` first.

## Bundled fonts

| File | Licence |
| --- | --- |
| PTSansNarrow-Bold.ttf | SIL Open Font License 1.1 ([text](Media/Licenses/PTSans-OFL.txt)) |
| LiberationSans-Regular.ttf | SIL Open Font License 1.1 ([text](Media/Licenses/LiberationSans-OFL.txt)) |
| FiraMono-Regular.ttf | SIL Open Font License 1.1 ([text](Media/Licenses/FiraMono-OFL.txt)) |
| DejaVuSansMono.ttf | Bitstream Vera / DejaVu licence ([text](Media/Licenses/DejaVu-LICENSE.txt)) |
| Expressway_Free.ttf | Freeware from Typodermic (Ray Larabie), see [typodermicfonts.com](https://typodermicfonts.com) |
| Prototype.ttf | Freeware, "free for personal use, freely distributed" |

Expressway and Prototype are freeware with personal-use terms. They are bundled as a convenience and remain the
property of their authors. If you are a rights holder and want a font removed, open an issue.

## License

The addon code is released under the [MIT License](LICENSE). Bundled fonts keep their own licences (above).
