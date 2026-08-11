# App info

Custom Xbox 360 application - XeUnshackle Max, an independent fork of [Byrom90/XeUnshackle](https://github.com/Byrom90/XeUnshackle).

## Build

Build Solution of [`XeUnshackle.sln`](XeUnshackle.sln) has to be done via 32-bit MSBuild like `C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe`, with `/p:Configuration=Release_LTCG /p:Platform="Xbox 360"` (note the space in the platform name - other values fail with MSB4126).

No test suite and no way to run the app in this environment (needs real Xbox 360 hardware/devkit). Verify changes by building cleanly and tracing the logic by hand.

## Xbox 360 SDK

Installed at `C:\Program Files (x86)\Microsoft Xbox 360 SDK` - the default location for the installers named in [BUILD.md](BUILD.md). Confirm it's there rather than assuming it.

- `include\xbox\*.h` - 190 plain text, greppable headers. Read these to check an XDK signature, struct or macro instead of guessing at one; the only alternative check is a full MSBuild run. `xtl.h` is the root include that `stdafx.h` pulls in, and the source of the `min`/`max` macros below.
- `lib\xbox\*.lib` - the libraries listed in the project's `AdditionalDependencies`. Worth a look when a link error blames a missing symbol.
- `doc\` is compiled help (`.chm`/`.cab`) and can't be read without extracting it, so don't try.

## Toolchain gotchas

- `min`/`max` are active function-like macros project-wide (`xtl.h` via `stdafx.h`, `NOMINMAX` is never defined). Bare `std::min(...)`/`std::max(...)` fails to compile (`C2589`/`C2059`). Use `std::min<T>(...)` with an explicit template argument instead - the macro only fires when immediately followed by `(`, and `<` breaks that match.
- `stdafx.h` is a precompiled header (`/Yu"StdAfx.h"`). New `#include`s must go inside `stdafx.h` itself, not before `#include "stdafx.h"` in a `.cpp` file - the latter is silently skipped (`C4627`).

## Branding

Fork name is "XeUnshackle Max". New user-facing strings (GUI text, dialog titles, docs prose) should say "XeUnshackle Max", not "XeUnshackle" - even though the class name, filenames, and `.sln`/`.vcxproj` are still plain "XeUnshackle" and stay that way.

## Writing

US English in docs and user-facing strings: "flavor", "localization", "customize", "color". The `Localisation`/`currentLocalisation` identifiers in the C++ sources are the one exception and stay as they are - they are established names in the code, not prose.
