# My Memories Album: Microsoft Store package kit

Source of truth: the INSTALLED copy at `%LOCALAPPDATA%\Programs\My Memories Album` (newer than GitHub and than `sandbox\payload` as of Nov 14, 2026). Nothing here changes the app itself.

## Files
- `build_msix.ps1`: stages a clean copy of the installed app (leaves out backups, old index/app copies, uninstaller, helper scripts), makes the logos from the app icon, fills the manifest, packs with `makeappx`.
- `AppxManifest.template.xml`: package manifest; launches `python\pythonw.exe` with a small `-c` start-up line that runs `app\MyMemoriesAlbum.pyw` (works regardless of the current folder).
- `make_assets.py`: logo PNGs from `MyMemoriesAlbum.ico` (run by the bundled Python).

## Needs (on Sandeep's PC)
Windows 10/11 SDK (provides `makeappx.exe`, `signtool.exe`). No admin rights are needed for the build; admin is needed once to trust the test certificate.

## Use
1. Rehearse (placeholder identity, cannot be uploaded): `.\build_msix.ps1 -TestSign`
2. After the name is reserved, rebuild with the real values from Partner Center (Product management > Product identity):
   `.\build_msix.ps1 -IdentityName "..." -Publisher "CN=..." -PublisherDisplayName "..."`
3. Upload `out\MyMemoriesAlbum_1.0.0.0_x64.msix` (unsigned on purpose; the Store signs it). Do not upload the `_testsigned` copy.
4. Option: `-ExcludeModels` leaves out the 26 MB `migan_512.onnx` (the in-app helper download then fetches it).

## Test checklist for the test-signed build (nothing here is verified yet)
Remove the normal Inno install first, or test on a PC without it; both can coexist but share the data folder name.
1. Starts from the Start menu; own app window opens; no black window; maximized.
2. Second launch opens the running window; Quit ends the program; close then reopen works.
3. Single-window rule across Edge and another browser still holds.
4. Trial/activation: trial starts; activation with a dedicated reviewer code works; a restart keeps it activated. (The licence anchors use HKCU\Software\PhotoTidy and ProgramData; MSIX may redirect the registry write, so check it.)
5. Edge app window: the app starts Edge with `--user-data-dir` inside the data folder. Check that the window reopens at the same size and that no stray Edge profile folders appear.
6. Photo folders: pick folders on C: and an external drive; scan; Albums, Duplicates, Organize, Collage, Edit and Save all work; Recycle Bin move works; collage saves to Pictures\My Memories Collages; Replace original puts the untouched file in Pictures\My Memories Originals.
7. AI helper: with the bundled `migan_512.onnx`, "White patches" repairs; face detection works; phone import works.
8. Uninstall from Settings > Apps removes the app; Pictures folders stay.
9. Windows Defender / SmartScreen shows nothing unusual.

## Partner Center answers (draft, to confirm when the form appears)
- `runFullTrust` justification: "My Memories Album is a Win32 desktop application (bundled Python runtime) that reads and organizes the user's own photo folders anywhere on the PC and the user's chosen drives. It must run at normal user privilege with full file access, so it cannot run in an app container."
- Notes for certification: explain the 7-day trial then an activation code (order receipt number) obtained from scanmymemories.shop, and give a **dedicated reviewer code** (make a new gratis code per `claude/gratis-activation-codes.md`; do not reuse the five test codes).
