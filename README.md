# homebrew-aspire-core

Personal **dogfood tap** for the Aspire CLI [`homebrew-core`][core] formula
candidate. The canonical formula source lives in
[`microsoft/aspire`][src] under `eng/homebrew-core/`; this tap hosts a
rendered copy pinned to a specific fork commit so the from-source install can
be exercised end-to-end before submission.

This is **not** the cask. For the prebuilt-binary cask, see the
`radical/homebrew-aspire` tap (`Casks/aspire.rb`).

## Install (builds from source)

```sh
brew tap radical/aspire-core
brew install radical/aspire-core/aspire
```

The formula carries **no bottle**, so `brew install` always builds from
source: it downloads the pinned fork archive, stages the per-RID .NET SDK,
runs `eng/homebrew-core/install-formula.sh`, and compiles the NativeAOT CLI.
Expect a few minutes of build time.

## Verify

```sh
aspire --version
aspire doctor        # Route should report "brew"
```

## Notes

- `Formula/aspire.rb` is a rendered snapshot: `url`/`version`/`sha256` and the
  four per-RID SDK resource SHAs are pinned. To point at a newer commit,
  re-render from the template in `microsoft/aspire` and push.
- `no_autobump!` is intentionally omitted (it is only valid in official
  Homebrew taps).

[core]: https://github.com/Homebrew/homebrew-core
[src]: https://github.com/microsoft/aspire/tree/main/eng/homebrew-core
