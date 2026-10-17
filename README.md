# GKI Kernel Build — android12-5.10 (Rama982-RE/r26-noSU)

GitHub Actions workflow that builds the
[`ramabondanp/android_kernel_common-5.10`](https://github.com/ramabondanp/android_kernel_common-5.10)
(`android12-5.10`) GKI kernel and packages it into an **AnyKernel3** flashable zip.

## How to run

1. Push this repository to GitHub.
2. Open **Actions → Build Kernel (android12-5.10 GKI) → Run workflow**.
3. Wait for the job to finish, then download the `AnyKernel3-Rama982-RE-r26-noSU`
   artifact from the run summary.

## What the workflow does

| Step | Detail |
|------|--------|
| Checkout | This repo (workflow, script, AnyKernel3 config) + the kernel source into `kernel/` |
| Toolchain | Downloads LLVM **23.1.3** (`x86_64`) from `mirrors.edge.kernel.org` |
| Build | Runs `scripts/build.sh` verbatim inside `kernel/` |
| KMI check | `KMI_function_symbols_test.py` is run; the build **fails** if CRCs mismatch |
| Package | Copies `out/arch/arm64/boot/Image` into AnyKernel3 and zips it |
| Artifact | `AnyKernel3-Rama982-RE-r26-noSU.zip` |

## Files

- `.github/workflows/build-kernel.yml` — the CI workflow.
- `scripts/build.sh` — your original build script, unchanged except
  `LLVM_VERSION` is set to `23.1.3`.
- `AnyKernel3/anykernel.sh` — GKI-friendly AnyKernel3 config
  (`do.devicecheck=0`, `do.modules=0`, `BLOCK=boot`, `IS_SLOT_DEVICE=1`).

## Notes

- **Manual trigger only.** Add a `push` or `schedule` block to `on:` if you
  want automatic builds.
- **Disk space.** The `jlumbroso/free-disk-space` step clears ~30 GB so the
  LTO link does not run out of space.
- **KMI verification is strict.** A CRC mismatch exits non-zero, which fails
  the workflow. Remove the `verify_kmi` call from the script if you want to
  make it non-fatal.
- **Slot devices.** `IS_SLOT_DEVICE=1` makes AnyKernel3 append `_a`/`_b` on
  A/B devices and fall back to the bare `boot` partition on A-only devices.
