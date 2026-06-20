# Changelog

All notable changes to SG Bus Live are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project aims to follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

App Store "What's New" release notes only apply to updates of an already-released version, so
the notes below are first published with version 1.1 onward (version 1.0 is the initial
release).

## [Unreleased]

### Added
- Bottom tab bar with four tabs: Arrivals, Favorites, Feedback, About.
- Favorites — save bus stops (persisted on-device) and recall them; swipe to delete.
- Feedback tab — send feature requests / bug reports via WhatsApp (+65 8866 6375).
- About tab — app description, developer (Tertiary Infotech Academy Pte Ltd), data credits, version.

## [1.0] — 2026-06-21

Initial App Store release (iPhone only). Build 4.

### Added
- GPS nearest-stop detection — auto-detects your location on launch and lists the closest bus
  stops with walking distance.
- Search at the top — enter a 6-digit postal code (geocoded via OneMap) or a 5-digit bus stop
  ID; or search by road / landmark.
- Bus-number filter chips — tap a service to drill into just that bus's arrivals.
- Live arrivals from LTA DataMall: next three timings per service with load (seats / standing /
  limited) and vehicle-type labels.
- Full LTA bus-stop directory (BusStops) fetched once and cached on disk for offline-fast
  nearest-stop lookups.
- App icon depicting a bus.

### Changed
- App name set to "SG Bus Live".
- iPhone-only (`TARGETED_DEVICE_FAMILY = 1`).

### Notes
- Added `NSLocationWhenInUseUsageDescription` for location access.
