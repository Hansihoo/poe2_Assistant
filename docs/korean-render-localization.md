# Korean Render Localization

This local overlay keeps PoB's internal data in English and translates text only when it is drawn.

Run the Korean display build with:

```bat
PathOfBuilding-PoE2-KR.cmd
```

The launcher runs `src/LaunchKorean.lua`, which installs `src/Modules/Localization.lua` and then loads the original `src/Launch.lua`.

The Korean launcher uses `runtime-ko` instead of the upstream `runtime` directory. The original runtime remains untouched for normal launches.

`runtime-ko` contains:

- a patched `SimpleGraphic.dll` built from `PathOfBuildingCommunity/PathOfBuilding-SimpleGraphic` commit `c062b29d05f9b82a7eab58179db673a2aac607b2`;
- matching dependency DLLs from that build;
- regenerated `runtime-ko/SimpleGraphic/Fonts/*.tgf` and `.tga` files with the Korean glyphs used by the Lua localization tables.

Official PoB updates may replace original manifest files such as `src/Launch.lua`, but they should not delete these local overlay files because they are not part of the upstream manifest. If an upstream update changes the rendering API, only the overlay hook or the `runtime-ko` rebuild should need adjustment.

The local SimpleGraphic source patch is stored at `tools/patches/simplegraphic-unicode-glyphs.patch`.

To temporarily disable the overlay:

```bat
set POB_KO_DISABLE=1
PathOfBuilding-PoE2-KR.cmd
```

The upstream `runtime` SimpleGraphic build still only ships ASCII bitmap glyphs for the bundled fonts. If `src/LaunchKorean.lua` is run directly against the upstream runtime, translated Hangul text is automatically skipped and the original English text is drawn instead. This prevents a broken UI while keeping the overlay installed.

The Korean launcher sets `POB_KO_FORCE=1` because `runtime-ko` has Hangul-capable fonts:

```bat
set POB_KO_FORCE=1
PathOfBuilding-PoE2-KR.cmd
```

The local SimpleGraphic patch keeps legacy ASCII font metadata working and adds explicit Unicode glyph metadata:

```text
GLYPH U+AC00 x y width left right;
```

The generated `.tgf` files keep the original `GLYPH x y width left right;` style for codepoints 0-127 and append Unicode glyph lines for non-ASCII codepoints.

Regenerate Korean font atlases after changing translations with:

```powershell
python .\tools\generate_korean_fonts.py --output .\runtime-ko\SimpleGraphic\Fonts
```

## Official Item And Stat Translations

Item/base names and item option text should come from official trade2 locale
metadata, not hand-written translations. Generate the official display table
after PoB updates, game patches, or trade metadata changes:

```powershell
python .\tools\generate_official_korean_locale.py
python .\tools\generate_korean_fonts.py --output .\runtime-ko\SimpleGraphic\Fonts
```

This writes:

```text
src/Modules/Localization/ko_official_generated.lua
```

The generated module joins:

- English official trade2 metadata from `https://www.pathofexile.com/api/trade2/data/*`;
- Korean official trade2 metadata from `https://poe.game.daum.net/api/trade2/data/*`.

The generated translations are display-only. They do not modify PoB's internal
English item data, modifier parser, calculations, build saves, or upstream data
files. If a displayed item option has no official Korean mapping, it remains in
English.

The loader reads modules in this order:

```text
ko.lua
ko_official_generated.lua
ko_user.lua
```

Use `ko_user.lua` only for local UI overrides. Do not put item/base/stat
translations there when the goal is official-only item text.

Add local translation overrides in:

```text
src/Modules/Localization/ko_user.lua
```

The translation layer also wraps text width measurement so common labels size against Korean text. Cursor index calculations are intentionally left on the original English text to avoid breaking editable fields.
