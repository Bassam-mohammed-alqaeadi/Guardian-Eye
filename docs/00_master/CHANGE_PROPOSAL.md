# Change Proposal — Flutter SDK Compatibility

## Current architecture

Guardian Eye Pro is now a Flutter/Dart project on Flutter 3.44.9 with Dart 3.12.2. The application depends on `flutter_localizations` from the Flutter SDK and directly declares `intl: ^0.19.0`.

## Problem and evidence

`flutter pub get` cannot resolve the dependency graph because the installed Flutter SDK pins `flutter_localizations` to `intl 0.20.2`, while the project constrains `intl` to `^0.19.0`. This is an SDK compatibility conflict, not a feature or architecture change.

## Proposed change

Adjust only the direct `intl` constraint from `^0.19.0` to `^0.20.2`, the version required by the Flutter SDK. No package is added or removed, and no product code or architectural layer is changed.

## Alternatives and decision

The alternative is installing an old Flutter SDK that still pins `intl` 0.19.x. That would move the project to an older toolchain without evidence that it is required, would reduce compatibility with the newly generated Android/iOS host projects, and would not address the original project's unresolved implementation defects. The safer choice is the smallest direct constraint correction compatible with the stable Flutter toolchain.

## Risks and verification

After the single-line change, run `flutter pub get`, `flutter analyze`, and `flutter test`. Any further dependency incompatibility will be documented and handled independently; no bulk upgrade is authorized.
