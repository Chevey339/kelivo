# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flutter Markdown Plus is a Flutter package that renders Markdown text into Flutter widgets. It's built on top of the Dart `markdown` package and supports GitHub Flavored Markdown by default. The package provides both `Markdown` (with scrolling) and `MarkdownBody` widgets, along with extensive customization options for styling, image handling, and interactive elements.

## Development Commands

### Testing
- Run all tests: `flutter test`
- Run tests with coverage: `rm -rf coverage && flutter test`
- Run all tests via test suite: `flutter test test/all.dart`
- Run a single test file: `flutter test test/[test_name].dart`

### Code Quality
- Format code: `dart format . -l 120` or `sh ./scripts/format.sh`
- Format only staged files: `sh ./scripts/format.sh --only-staged`
- Format with exit-on-change: `sh ./scripts/format.sh --set-exit-if-changed`
- Analyze code: `flutter analyze --no-pub .`
- Full validation: `./validate.sh` (runs clean, pub get, format, analyze, and test)

### Package Management
- Get dependencies: `flutter pub get`
- Clean build: `flutter clean`

### Example App
- Run example app: `cd example && flutter run`
- Demos are in `example/lib/demos/` showcasing various features
- Shared widgets in `example/lib/shared/` include reusable demo components and sample custom syntax implementations

## Architecture

### Core Components

**Main Entry Point** (`lib/flutter_markdown_plus.dart`)
- Exports the three main modules: builder, style_sheet, and widget

**Widget Layer** (`lib/src/widget.dart`)
- `Markdown`: Scrollable markdown widget with padding
- `MarkdownBody`: Non-scrollable markdown widget for embedding
- `MarkdownRaw`: Base widget without Material Design theming
- Callback typedefs for link taps, selection changes, and custom builders

**Builder Layer** (`lib/src/builder.dart`)
- `MarkdownBuilder`: Converts markdown AST nodes to Flutter widgets
- Handles all markdown elements: headers, paragraphs, lists, tables, images, etc.
- Manages text styling, link handling, and custom element rendering
- Block vs inline element handling with proper nesting

**Style Layer** (`lib/src/style_sheet.dart`)
- `MarkdownStyleSheet`: Comprehensive theming system
- Integrates with Material Design themes
- Supports custom text styles, colors, decorations, and spacing

### Platform Abstractions
- `_functions_io.dart`: IO platform implementations
- `_functions_web.dart`: Web platform implementations
- Conditional imports handle platform differences

### Extension Points

**Custom Builders**
- `imageBuilder`: Custom image widget rendering
- `checkboxBuilder`: Custom checkbox rendering  
- `bulletBuilder`: Custom bullet point rendering

**Syntax Extensions**
- Supports markdown package's extension system
- Default: GitHub Flavored Markdown
- Can add emoji syntax, custom inline/block syntaxes

**Selection & Interaction**
- Configurable text selection behavior
- Link tap handling with custom callbacks
- Integration with Flutter's SelectionArea

## Key Features

- **Markdown Parsing**: Built on `markdown` package AST
- **Rich Styling**: Material Design integration with custom overrides  
- **Image Support**: Network, local, and asset images with `resource:` prefix
- **Table Rendering**: Full table support with custom styling
- **Interactive Elements**: Checkboxes, links with tap handlers
- **Text Selection**: Configurable selection with callbacks
- **Extensibility**: Plugin system for custom syntax and rendering

## Testing Strategy

Tests are comprehensive and organized by feature:
- Individual element tests (headers, lists, images, etc.)
- Style sheet testing
- Selection and interaction testing  
- Platform compatibility testing
- Mock-based image testing

The `test/all.dart` file runs the complete test suite.

## Code Style

- Line length: 120 characters (configured in `pubspec.yaml`)
- Follows Flutter/Dart team's analysis_options.yaml with minor modifications
- Public API documentation required (`public_member_api_docs`)
- Strict type checking enabled
- Uses `prefer_single_quotes` and other Flutter conventions