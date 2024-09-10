# Changelog

## 2.0.0

Breaking changes:
  * The webpack plugin has been converted to a loader, you will need to adapt your configuration, see the webpack plugin's readme.
  * The parcel v1 plugin has been dropped.

Bug fixes:
  * Fix multiple compilations in watch mode

## 1.3.1

Bug fixes:
  * Correctly handle errors when building in webpack plugin

## 1.3.0

New features:
  * Add projectRoot option

## 1.2.1

Bug fixes:
  * Fix env files variables merge

## 1.2.0

New features:
  * Add support for global variable replacement through env vars

## 1.1.4

Bug fixes:
  * Fix generated code for routes with variable name conflicting with elm reserved keywords

## 1.1.3

Bug fixes:
  * Fix generation of translations with a domain that contains characters not allowed to appear in an elm module name

## 1.1.2

Bug fixes:
  * Fix bad invocation of routing command in production mode
  * Fix bogus error message
  * Add `translations` to watched folders
  * Allow configuration of watches

## 1.1.1

Bug fixes:
  * Fix translation support in the parcel plugin

## 1.1.0

New features:
  * Add parcel support

Bug fixes:
  * Correctly handle the absence of routes in symfony

## 1.0.5

Bug fixes:
  * Update dependencies

## 1.0.4

Bug fixes:
  * Set default values for undefined options (required by more recent versions of schema-utils).
  * Avoid invalid function names in generated code.

## 1.0.3

Bug fixes:
  * Fix support for webpack 4.x.

## 1.0.2

Bug fixes:
  * Add support for webpack 4.x. We now support both webpack 3.x and 4.x.

## 1.0.1

Bug fixes:
  * Translations json parser is now more lenient by allowing non strings messages. Integer, float, and boolean are converted to string, null, array and object are replaced with an empty string.

## 1.0.0

New features:
  * Generate routes from symfony's routing, with variables support
  * Generate translations from symfony's translations, with variables and pluralization support
  * Support for elm 0.18 and 0.19

[//]: # (## x.y.z)
[//]: # (Breaking changes:)
[//]: # (New features:)
[//]: # (Bug fixes:)
