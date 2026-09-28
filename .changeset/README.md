# Changesets

Each file in this folder, other than this one and `config.json`, is a **changeset**: a note that says a change is waiting to be released, how big it is, and what to tell players about it.

```md
---
"magiteknician": minor
---

Frost Bolt now chills whoever it strikes.
```

## Adding one

```sh
npx changeset
```

It asks how big the change is and what to say about it, and writes the file. Commit the file along with the change.

You can also write the file by hand. Give it any name ending in `.md`.

## How big is the change?

| Bump | When | 1.4.2 becomes |
| :- | :- | :- |
| `patch` | A fix. Nothing new, and nothing plays differently except what was broken. | 1.4.3 |
| `minor` | Something new: a spell, an opponent, a mode, a setting. | 1.5.0 |
| `major` | Something that breaks what came before: old saves no longer load, or players on the old version can no longer duel players on the new one. | 2.0.0 |

If several changesets are waiting, the release takes the biggest bump among them.

A change that players would never notice (tests, CI, the README) needs no changeset.

## What happens to them

When a changeset reaches `main`, a pull request is opened that promotes everything waiting into a release. See **Releases** in the README at the root.
