# Finifugal

A single-file Criminality UI: ESP, aim, chams, POI markers, a menu, and a
keybind editor. One file, no dependencies.

## Load it

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/elclubdelahorro/Finifugal/main/criminality.lua"))()
```

Or paste `criminality.lua` straight into the executor. The gate asks once and
remembers the key in `CriminalityOD/key.txt`.

## Files

| file | what it is |
|---|---|
| `criminality.lua` | the build |
| `status.json` | the switch |
| `plug.ps1` | `.\plug.ps1 kill "reason"` / `alive` / `status` |

## The switch

`status.json` is fetched at launch and polled every 30 seconds.

```json
{ "kill": false, "reason": "" }
```

Flip `kill` to `true` and commit — or delete the file — and a running copy shuts
itself down, a launch is refused, and a launch with no network is refused too
(`strict = true`). Set it back to `false` to let people back in.

**Latency is up to five minutes, measured.** GitHub serves raw files with
`Cache-Control: max-age=300` and ignores a `?t=` query, so a poll can read an
edge copy from before the commit. Deleting the file gets the same window.

## Keys

One baked hash. Rebake with `Finifugal.bake("new-key")` in an executor console,
paste the printed digest into `Config.key.hash`, upload. Every copy that was
handed out stops working on its next poll.

## The ceiling

The source is public. Anyone who reads it can strip the gate in one line. The
kill switch still stops an unmodified copy, because that copy polls
`status.json`; a copy someone edited does not poll anything you control.
