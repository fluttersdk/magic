# Documentation Authoring Guide

This guide explains how to write, update, and maintain documentation pages in Magic's `doc/` directory so they stay accurate, consistently formatted, and correctly rendered on fluttersdk.com.

- [Page Template](#page-template)
- [Folder Taxonomy](#folder-taxonomy)
- [Downstream Rendering](#downstream-rendering)
- [API Accuracy Rule](#api-accuracy-rule)
- [Per-Feature Doc-Sync Checklist](#per-feature-doc-sync-checklist)
- [Code Samples](#code-samples)
- [What Not to Add](#what-not-to-add)

<a name="page-template"></a>
## Page Template

Every page (new and rewritten) must conform to this structure exactly:

```
# Page Title

One-line description sentence (plain prose, feeds the downstream page description).

- [Section One](#section-one)
- [Section Two](#section-two)

<a name="section-one"></a>
## Section One

Content.

<a name="section-two"></a>
## Section Two

Content.
```

Rules derived from this template:

- **H1 title**: the bare `# Title` line, no YAML frontmatter above or below it.
- **Lead sentence**: a single plain-prose sentence immediately after the H1, before the TOC bullets. fluttersdk.com's `DocsScaffolder` extracts this paragraph as the page description (truncated at 160 characters); omitting it leaves the page with an empty description.
- **Anchor-TOC**: a bulleted `- [Label](#anchor)` list before the first section. Every TOC entry must have a matching `<a name="anchor">` in the body, and every `<a name>` in the body must appear in the TOC. Mismatches break in-page navigation.
- **Section anchors**: `<a name="kebab-case-slug"></a>` on the line immediately before the `##` or `###` heading. Use the same kebab-case slug in both the TOC link and the anchor.
- **No YAML frontmatter**: do not add `---` blocks, `title:`, `description:`, or any ordering metadata. The downstream site derives all of this from the page itself (see [Downstream Rendering](#downstream-rendering)).

<a name="folder-taxonomy"></a>
## Folder Taxonomy

Pages live under `doc/` in one of these subdirectories. Do not create new subdirectories; place new pages in the closest existing folder.

| Folder | Content |
|--------|---------|
| `getting-started/` | Installation, configuration, service providers, directory structure |
| `architecture/` | Facades, service container, request lifecycle |
| `basics/` | Routing, controllers, middleware, views, forms, HTTP client, UI helpers |
| `security/` | Authentication, authorization, encryption, vault |
| `database/` | Getting started with the DB facade, migrations, seeding |
| `eloquent/` | Eloquent ORM getting started, mutators, serialization |
| `digging-deeper/` | Broadcasting, cache, events, validation, localization, logging, file storage, file picker, launch, session, encryption, carbon |
| `testing/` | Getting started with testing, HTTP tests, database testing, facade fakes |
| `packages/` | Magic CLI, devtools (dusk + telescope), and other first-party integrations |
| `contributing/` | Contribution guide (code) and this authoring guide (docs) |

<a name="downstream-rendering"></a>
## Downstream Rendering

fluttersdk.com syncs `doc/` via its `DocsScaffolder` (triggered by the `POST /api/v1/docs/magic/sync` endpoint or the `DocsSync` command). The scaffolder reads:

- **H1** to set the page title.
- **Lead paragraph** (the single sentence after H1, before the TOC) to set the page description.
- **Directory name** to determine the section label (converted via `Str::headline`).

Navigation order and menu labels live in the `doc_pages` database table, curated by the site admin in Filament. The `doc/` directory needs no nav manifest, no ordering file, and no frontmatter. Adding any of these would have no effect on the rendered site.

<a name="api-accuracy-rule"></a>
## API Accuracy Rule

Every documented method, signature, and parameter must exist in the current `lib/src/` code. This is the backbone of the overhaul that produced these docs, and it must stay the backbone going forward.

Before writing or updating a code sample:

1. Open the relevant facade in `lib/src/facades/<name>.dart` (or the concrete class under `lib/src/`) and read the actual method signatures.
2. Copy the method name and parameter list verbatim into the example. Do not invent parameters or default values that are not in the source.
3. If a method you expected to find is absent, do not document it. File a separate issue or add it to the framework first.

Corollary: when a facade or class is renamed or a method is removed, update the matching doc page in the same change set. The `CLAUDE.md` Post-change sync rule (`doc/` item) mandates this; see the [Per-Feature Doc-Sync Checklist](#per-feature-doc-sync-checklist) below for the detailed steps.

<a name="per-feature-doc-sync-checklist"></a>
## Per-Feature Doc-Sync Checklist

When a facade or framework feature changes, apply this checklist before marking the work done. This checklist is the doc-layer expansion of the Post-change sync rule in `CLAUDE.md` (section "Post-change sync").

**1. Identify the matching doc page.**

| Changed surface | Primary doc page |
|-----------------|------------------|
| `Auth` facade | `doc/security/authentication.md` |
| `Cache` facade | `doc/digging-deeper/cache.md` |
| `Config` facade | `doc/getting-started/configuration.md` |
| `Crypt` facade | `doc/security/encryption.md` |
| `DB` facade | `doc/database/getting-started.md` |
| `Echo` facade / broadcasting | `doc/digging-deeper/broadcasting.md` |
| `Event` facade | `doc/digging-deeper/events.md` |
| `Gate` facade / policies | `doc/security/authorization.md` |
| `Http` facade / HTTP client | `doc/basics/http-client.md` |
| `Lang` facade | `doc/digging-deeper/localization.md` |
| `Launch` facade | `doc/digging-deeper/launch.md` |
| `Log` facade | `doc/digging-deeper/logging.md` |
| `Pick` facade / file picker | `doc/digging-deeper/file-picker.md` |
| `Route` facade / routing | `doc/basics/routing.md` |
| `Schema` facade / migrations | `doc/database/migrations.md` |
| `Session` facade | `doc/digging-deeper/session.md` |
| `Storage` facade | `doc/digging-deeper/file-storage.md` |
| `Vault` facade | `doc/security/vault.md` |
| Eloquent model / ORM | `doc/eloquent/getting-started.md` |
| Service providers / container | `doc/architecture/service-container.md` and `doc/getting-started/service-providers.md` |
| Middleware | `doc/basics/middleware.md` |
| UI helpers (`MagicBuilder`, etc.) | `doc/basics/ui-helpers.md` |
| Validation rules | `doc/digging-deeper/validation.md` |
| Forms / `FormRequest` | `doc/basics/forms.md` |
| Testing fakes | `doc/testing/facades.md` |
| CLI commands | `doc/packages/magic-cli.md` |
| Dusk / telescope integration | `doc/packages/magic-devtools.md` |

**2. Update the page.**

- Add, rename, or remove the section(s) that cover the changed surface.
- For a renamed method: update every occurrence in prose, code samples, and the TOC.
- For a removed method: delete its section and its TOC entry.
- For a new method: add a section with a dart code example (see [Code Samples](#code-samples)), add a TOC entry, and add the matching `<a name>` anchor.

**3. Verify the method set.**

Open the facade source and compare it line by line against the page's documented methods. Confirm every documented method still exists with the same signature. Remove or correct any that drifted.

**4. Check TOC-to-anchor consistency.**

Every `- [Label](#anchor)` in the TOC must have a corresponding `<a name="anchor"></a>` in the body. Every `<a name>` in the body must appear in the TOC. Fix any orphaned entry on either side.

**5. For a brand-new feature.**

Choose the correct folder from the [Folder Taxonomy](#folder-taxonomy), create the file, and write it according to the [Page Template](#page-template). H1, lead sentence, TOC, then sections with anchors.

<a name="code-samples"></a>
## Code Samples

Use fenced dart blocks for all Dart/Flutter code:

````
```dart
final value = Config.get<String>('app.name', 'Magic');
```
````

Import the public barrel at the top of samples that need it:

```dart
import 'package:magic/magic.dart';
```

For test samples, use the testing barrel:

```dart
import 'package:magic/testing.dart';
```

For CLI-related samples, use the CLI barrel:

```dart
import 'package:magic/cli.dart';
```

Keep samples minimal: show the method call and its most common parameters. Omit boilerplate (`main()`, `MaterialApp`, widget scaffolding) unless the scaffolding is the point of the example.

<a name="what-not-to-add"></a>
## What Not to Add

- **No YAML frontmatter.** The `---` block adds no downstream value and is explicitly excluded.
- **No nav manifest or ordering file.** Navigation is DB-curated on fluttersdk.com; a repo-side manifest would be ignored.
- **No invented version attribution** such as "Added in v1.2". Use `CHANGELOG.md` and release notes for that.
- **No `<x-preview>` live-preview tags.** Magic's `preview_url` is null (no preview app is configured), so the tag renders a "not available" placeholder.
- **No new subdirectories.** The folder taxonomy is locked; place pages in the closest existing folder.
- **No em-dash or en-dash.** Use comma, colon, semicolon, period, or parentheses instead.
