# FolderPeek Fixtures

Verification fixtures are generated locally by scripts instead of being tracked in Git.

- Run `./Scripts/create_test_fixtures.sh` to recreate `Fixtures/Verification/`.
- `./Scripts/verify_quicklook_runtime.sh` creates the verification fixtures automatically when they are missing.

Generated fixture directories such as `Fixtures/M0/` and `Fixtures/Verification/` are ignored because they include large archives, runtime-only permission fixtures, and reproducible test data.
