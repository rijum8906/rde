import 'package:core/theme/domain/entities/appearance_mode.dart';
import 'package:dbus/dbus.dart';

/// Author-owned manifest of an installed theme, as returned by
/// `org.rde.Theme.GetThemeManifest`.
///
/// Manifests are read-only to the service: they describe the variants the
/// theme author shipped, while user choices live in the service settings.
class ThemeManifest {
  const ThemeManifest({
    required this.schemaVersion,
    required this.name,
    required this.displayName,
    required this.description,
    required this.version,
    required this.defaultVariant,
    required this.variants,
    this.author,
    this.license,
  });

  /// Identifier of the built-in wallpaper-derived theme.
  static const String dynamicId = 'rde-dynamic';

  /// Schema version of the manifest format.
  final int schemaVersion;

  /// Unique identifier of the theme.
  final String name;

  /// User-facing name shown in pickers.
  final String displayName;

  /// Short description of the theme.
  final String description;

  /// Semantic version of the theme package.
  final String version;

  /// Identifier of the variant the service selects by default.
  final String defaultVariant;

  /// Every variant shipped by the theme.
  final List<ThemeVariant> variants;

  /// Optional author name or contact.
  final String? author;

  /// Optional license identifier such as `MIT`.
  final String? license;

  /// Returns the variant matching [mode] and [contrast].
  ///
  /// # Returns
  /// The matching variant, the default variant when no exact match exists, or
  /// the first variant when the default identifier is unknown.
  ThemeVariant? variantFor(
    AppearanceMode mode, [
    ContrastLevel contrast = ContrastLevel.normal,
  ]) {
    // Step 1: Prefer the exact (mode, contrast) pair.
    for (final variant in variants) {
      if (variant.mode == mode && variant.contrast == contrast) {
        return variant;
      }
    }

    // Step 2: Fall back to the declared default variant.
    for (final variant in variants) {
      if (variant.id == defaultVariant) {
        return variant;
      }
    }

    // Step 3: Keep pickers usable even with a malformed manifest.
    return variants.isEmpty ? null : variants.first;
  }

  /// Decodes the struct returned by `GetThemeManifest`.
  ///
  /// Signature: `(ussssssa{s(uusss)}s)`.
  ///
  /// # Errors
  /// Throws a [FormatException] when the reply has an unexpected shape.
  factory ThemeManifest.fromDbus(DBusValue value) {
    if (value is! DBusStruct || value.children.length < 9) {
      throw const FormatException('GetThemeManifest returned an unknown shape');
    }

    final fields = value.children;
    final variants = <ThemeVariant>[];
    final rawVariants = fields[7];
    if (rawVariants is DBusDict) {
      for (final entry in rawVariants.children.entries) {
        variants.add(ThemeVariant.fromDbus(entry.key.asString(), entry.value));
      }
    }

    return ThemeManifest(
      schemaVersion: fields[0].asUint32(),
      name: fields[1].asString(),
      displayName: fields[2].asString(),
      description: fields[3].asString(),
      author: _optional(fields[4].asString()),
      license: _optional(fields[5].asString()),
      version: fields[6].asString(),
      variants: variants,
      defaultVariant: fields[8].asString(),
    );
  }
}

/// One variant shipped by a theme manifest.
class ThemeVariant {
  const ThemeVariant({
    required this.id,
    required this.mode,
    required this.contrast,
    required this.filePath,
    this.displayName,
    this.preview,
  });

  /// Identifier used to select this variant inside its theme.
  final String id;

  /// Appearance this variant renders.
  final AppearanceMode mode;

  /// Contrast requirement of this variant.
  final ContrastLevel contrast;

  /// Path of the variant payload, relative to the theme directory.
  final String filePath;

  /// Optional label shown in pickers.
  final String? displayName;

  /// Optional preview image, relative to the theme directory.
  final String? preview;

  /// Decodes the `(uusss)` variant descriptor stored in the manifest map.
  factory ThemeVariant.fromDbus(String id, DBusValue value) {
    if (value is! DBusStruct || value.children.length < 5) {
      throw FormatException('variant "$id" returned an unknown shape');
    }

    final fields = value.children;
    return ThemeVariant(
      id: id,
      mode: AppearanceMode.fromIndex(fields[0].asUint32()),
      contrast: ContrastLevel.fromIndex(fields[1].asUint32()),
      displayName: _optional(fields[2].asString()),
      filePath: fields[3].asString(),
      preview: _optional(fields[4].asString()),
    );
  }
}

/// Maps an empty D-Bus string onto `null`.
String? _optional(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  return value;
}
