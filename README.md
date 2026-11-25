# Finifugal

This repo is the **switch**, not the build.

`status.json` is the only file the cheat reads. It is fetched at launch and
polled every 30 seconds.

```json
{ "kill": false, "reason": "" }
```

Flip `kill` to `true` and commit — or delete the file — and:

- a running copy shuts itself down on its next poll,
- a launch is refused,
- a launch with no network is refused too (`strict = true`).

Set it back to `false` and commit to let people back in. Ungraceful deletion is
the point: a 404 is a kill when `strict` is on.

**Latency is up to five minutes, measured.** GitHub serves raw files with
`Cache-Control: max-age=300` and ignores a `?t=` query, so the poll can read an
edge copy from before the commit. Deleting the file or the repo gets the same
window.

## Where the build lives

The script is not in this repo. It is served by the Cloudflare Worker in
`cheats/keygate/`, and only to a request that carries a valid key:

```
GET /auth?k=<key>&hwid=<machine>
  200  the Lua source, stamped with the key's hash
  403  not licensed | device limit | <kill reason>
  503  no source uploaded
```

A copy that does not pass the gate never receives the code. Every served copy
carries `-- [f2:<hash8>]` on its second line, so a build that leaks names the
key that leaked it.

The repo stays public because `status.json` has to be readable by every client.
Nothing else in it is worth reading.
