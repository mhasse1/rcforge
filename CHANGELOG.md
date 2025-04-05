# Changelog

All notable changes to rcForge will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v0.2.1.html).

## [Unreleased]

## [0.2.0] - 2025-03-29
### Changed
- Adopted new versioning scheme - what was previously known as v2.0 is now v0.2.0
- Changed all version references throughout the codebase
- Updated documentation to reflect pre-release status

### Added
- Comprehensive include system for modular shell function organization
- Machine-specific configurations based on hostname
- More robust error handling when loading configurations

### Fixed
- Bash version detection and graceful fallback for older versions
- Path handling for various installation methods

## [0.1.0] - 2025-02-01
### Added
- Initial basic implementation
- Cross-shell support for Bash and Zsh
- Sequence-based loading system
- Early version of conflict detection

[Unreleased]: https://github.com/mhasse1/rcforge/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/mhasse1/rcforge/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/mhasse1/rcforge/releases/tag/v0.1.0
# EOF
