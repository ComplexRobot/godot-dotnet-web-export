# Godot Engine 4.x C# .NET - Web Export

Simple project which enables experimental web export support for C# projects.

Visit the [Releases](https://github.com/ComplexRobot/godot-dotnet-web-export/releases) for a pre-built binary for Windows.
On macOS and Linux you can build the editor from source and use the web export templates from the Windows release
(see [macOS and Linux](#macos-and-linux)).

More information is in the release notes.


### Important Information

> [!WARNING]
> Games exported for the web lack support for some features.
>
> Does not support GDExtensions due to the .NET runtime being built without position-independent code.
>
> From the [raulsntos PR](https://github.com/godotengine/godot/pull/106125):
> * Globalization doesn't work, so for now we're always enabling
[invariant mode](https://learn.microsoft.com/en-us/dotnet/core/runtime-config/globalization#invariant-mode).
> * (...) some BCL APIs will not work (i.e.: crypto APIs)

> [!TIP]
> If you are uploading to [itch.io](https://itch.io/) - _[xr0gu3](https://github.com/xr0gu3/net-web-example)_:
> > (don't forget to enable **SharedArrayBuffer support** on itch project dashboard).


### Requirements

- The `.csproj` `TargetFramework` must be `net9.0`, i.e., `<TargetFramework>net9.0</TargetFramework>`.
  - You will need the .NET 9.0 SDK installed, or the .NET 10.0 SDK with the `wasm-tools-net9` workload
    (see [WASM Tools Installation](#wasm-tools-installation)).

- Your project must include a `Program.cs` containing at least one top-level statement.
  - The simplest is a `Program.cs` simply containing `{}`. (Sample file included.)

- Done automatically by the `install.bat` included in the release (Windows) or by `install.sh` in this repository
  (macOS and Linux):
  - Copy the included `web_release.zip` and `web_debug.zip` files to the Godot export templates folder
    as well as the included `nuget` folder to a valid NuGet source:

    | OS      | Export templates                                                         | NuGet source               |
    |---------|--------------------------------------------------------------------------|----------------------------|
    | Windows | `%AppData%\Godot\export_templates\<version>.<status>.mono`               | `%AppData%\NuGet\nuget`    |
    | macOS   | `~/Library/Application Support/Godot/export_templates/<version>.<status>.mono` | `~/.nuget/NuGet/nuget` |
    | Linux   | `~/.local/share/godot/export_templates/<version>.<status>.mono`          | `~/.nuget/NuGet/nuget`     |

  - The .NET workload `wasm-tools` (or `wasm-tools-net9` on the .NET 10.0 SDK) must be installed.

> [!TIP]
> If you are using self-contained mode, you will need to copy the web export templates to the
`editor_data\export_templates\<version>.<status>.mono` folder.

> [!NOTE]
> You may need to add these lines to your `.csproj` (before the `</Project>`):
> ```xml
> <ItemGroup>
>   <TrimmerRootAssembly Include="System.Private.CoreLib" />
>   <TrimmerRootAssembly Include="System.Runtime" />
> </ItemGroup>
> 
> ```


### WASM Tools Installation

Exporting for the web requires the .NET workload `wasm-tools` to be installed.

The included `install.bat` will attempt to install `wasm-tools` for your highest installed .NET SDK as well as .NET 9.0.

This is installed via the command line `dotnet workload install wasm-tools`.

A separate .NET 9.0 SDK is not required if you have the .NET 10.0 SDK. It can build `net9.0` projects
for the web once the `wasm-tools-net9` workload is installed (the plain `wasm-tools` workload on .NET 10.0
only covers `net10.0`):

```sh
dotnet workload install wasm-tools-net9
```

`install.sh` picks the right workload for your SDK.

You can use a `global.json` (sample file included) to control the .NET SDK version used.


### macOS and Linux

There is no pre-built editor for macOS or Linux yet, but the editor builds from the same Godot source as the
Windows release, and the `web_release.zip` and `web_debug.zip` templates from the Windows release work with it
unchanged. The official Godot .NET editor can't be used because it refuses to export C# projects to the web.

These steps were tested on an Apple Silicon Mac with only the Xcode Command Line Tools installed.
Linux should be similar with `platform=linuxbsd`, but has not been tested.

1. Install Python 3, SCons (`pip install scons`) and the .NET SDK.

2. Get the Godot source used for the release. The `godot` submodule of this repository points at it:
   ```sh
   git clone --recursive https://github.com/ComplexRobot/godot-dotnet-web-export
   cd godot-dotnet-web-export/godot
   ```

3. Build the editor. Without full Xcode the Metal and Vulkan drivers can't be built, so they are turned off and
   the editor uses the Compatibility renderer, which is fine for exporting:
   ```sh
   scons platform=macos arch=arm64 target=editor module_mono_enabled=yes vulkan=no metal=no accesskit=no
   ```

4. Generate the C# glue and build the C# assemblies and NuGet packages:
   ```sh
   bin/godot.macos.editor.arm64.mono --headless --generate-mono-glue modules/mono/glue
   python3 modules/mono/build_scripts/build_assemblies.py --godot-output-dir=./bin --godot-platform=macos --push-nupkgs-local ~/.nuget/NuGet/nuget
   ```

5. Download the Windows release zip and extract it, then run `install.sh` from this repository with the extracted
   folder (the `.exe` files in it aren't needed):
   ```sh
   bash ../install.sh ~/Downloads/Godot_v4.7.2-stable_mono_web_export_win64
   ```
   This copies the web templates and NuGet packages, registers `~/.nuget/NuGet/nuget` as a NuGet source and
   installs the WASM workload.

6. Run `bin/godot.macos.editor.arm64.mono` and open your project.


### Troubleshooting

- **Export fails with `NETSDK1147` ("workloads must be installed: wasm-tools-net9")** even though
  `dotnet workload list` shows the workload. We saw this with Homebrew's `dotnet`, which installs workloads into
  `~/.dotnet`: the first install left the packs folder empty. Run `dotnet workload repair`.

- **The game still uses the official Godot packages.** NuGet uses any copy of `Godot.NET.Sdk`, `GodotSharp` or
  `GodotSharpEditor` already in the global packages folder (`~/.nuget/packages` or `%UserProfile%\.nuget\packages`)
  before it looks at the local source. If you restored the official packages of the same version earlier, delete
  those folders from the cache and rebuild.

- **`InvalidOperationException: JsonSerializerIsReflectionDisabled`.** The web export trims assemblies and turns off
  reflection-based `System.Text.Json` serialisation. Either use a source-generated `JsonSerializerContext`, or turn
  reflection back on for web builds and keep the assemblies you deserialise into from being trimmed:
  ```xml
  <PropertyGroup Condition=" '$(GodotTargetPlatform)' == 'web' ">
    <JsonSerializerIsReflectionEnabledByDefault>true</JsonSerializerIsReflectionEnabledByDefault>
  </PropertyGroup>
  <ItemGroup Condition=" '$(GodotTargetPlatform)' == 'web' ">
    <TrimmerRootAssembly Include="YourLibrary" />
  </ItemGroup>
  ```

- **The page hangs.** The browser's main thread can't block waiting for worker threads, so never block Godot's main
  thread on other threads: avoid `Parallel.For`, `Task.Wait()` and `.Result` on a task that hasn't finished.
  Starting work with `Task.Run` and checking `IsCompleted` each frame is fine. Use `OperatingSystem.IsBrowser()` if
  you need a different code path on the web.

- **Startup is slow.** C# runs on the Mono interpreter in the browser (the assemblies are embedded and there is no
  AOT compilation), so heavy C# work is much slower than on desktop. Show a loading screen while it runs.

- **The game looks frozen in Chrome.** Chrome pauses `requestAnimationFrame` for hidden or fully covered windows.
  Check `document.visibilityState` in the console before assuming the game has hung.

- **Threads don't work when testing locally.** The page needs cross-origin isolation, which means serving it with the
  `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp` headers.
  `python3 -m http.server` doesn't send them. Godot's own `platform/web/serve.py` does, or save this as `serve.py`
  and run `python3 serve.py` from the export folder:
  ```python
  from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

  class Handler(SimpleHTTPRequestHandler):
      extensions_map = {**SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm"}

      def end_headers(self):
          self.send_header("Cross-Origin-Opener-Policy", "same-origin")
          self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
          super().end_headers()

  print("Serving on http://localhost:8000")
  ThreadingHTTPServer(("localhost", 8000), Handler).serve_forever()
  ```


### Credit

- [raulsntos](https://github.com/godotengine/godot/pull/106125): For their pull request implementing built-in editor support.
- [xr0gu3](https://github.com/xr0gu3/net-web-example): For providing a docker image and example repo.


### Development Information

In addition to their changes, I've added a change to how export templates are generated based upon the fix in xr0gu3's docker build.

This changes the `js` file in the template so that you can export directly from the editor with no post-export changes needed.

Custom build of godot here: [ComplexRobot/godot/4.7](https://github.com/ComplexRobot/godot/tree/4.7)
(the `godot` submodule of this repository points at the exact commit used for the release).

It is the latest stable version of godot with the PR by raulsntos merged in. (Plus a small change added by xr0gu3.)
