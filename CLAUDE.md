<!-- qwd:begin -->
## Design system

- The design system is the git submodule `design/qwd/` (Quantum Works Design, https://design.luthopian.de).
  Never edit it: a hook blocks edits and writing commands there.
- Tokens are read from `design/qwd/dist/tickerline/<mode>/` (`tokens.json`, `tokens.css`, …).
- Before asking for anything, check `design/qwd/dist/catalog.md` or `qwd catalog search "<what>"`.
- To ask for something missing: `qwd request new --product tickerline --kind <kind> --title "…" --body-file req.md`,
  then `qwd steward QWD-<n> --wait`. Until it is merged, keep a local value marked `# TODO(QWD-<n>)`.
- After the merge, bump with `git submodule update --remote design/qwd`, then run
  `python3 design/qwd/tools/hooks/sync_copies.py` (it rewrites the synced copies listed in
  `design/qwd-copies.toml`, if there is one), then commit the pointer and the copies together
  (`git add design/qwd <copies>`). The copies are blocked like the submodule; never edit them by hand.
- Follow renamed or removed tokens in `design/qwd/CHANGELOG.md` when you bump.
<!-- qwd:end -->
