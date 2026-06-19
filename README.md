<p align="center">
  <img src="https://raw.githubusercontent.com/fluttersdk/magic/master/.github/magic-logo.svg" width="120" alt="Magic Logo" />
</p>

<h1 align="center">Magic</h1>

<p align="center">
  <strong>The Laravel Experience for Flutter.</strong><br/>
  Build production-ready Flutter apps with Facades, Eloquent ORM, Service Providers, and an IoC Container. If you know Laravel, you already know Magic.
</p>

<p align="center">
  <a href="https://pub.dev/packages/magic"><img src="https://img.shields.io/pub/v/magic.svg" alt="pub package"></a>
  <a href="https://github.com/fluttersdk/magic/actions"><img src="https://img.shields.io/github/actions/workflow/status/fluttersdk/magic/ci.yml?branch=master&label=CI" alt="CI"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
  <a href="https://pub.dev/packages/magic/score"><img src="https://img.shields.io/pub/points/magic" alt="pub points"></a>
  <a href="https://github.com/fluttersdk/magic/stargazers"><img src="https://img.shields.io/github/stars/fluttersdk/magic?style=flat" alt="GitHub stars"></a>
</p>

<p align="center">
  <a href="https://magic.fluttersdk.com">Documentation</a> ·
  <a href="https://pub.dev/packages/magic">pub.dev</a> ·
  <a href="https://github.com/fluttersdk/magic/issues">Issues</a>
</p>

---

> [!NOTE]
> Requires Flutter >= 3.41.0 and Dart >= 3.11.0. **Alpha**: Magic is under active development and APIs may change before 1.0. [Star the repo](https://github.com/fluttersdk/magic) to follow progress.

## Installation

```bash
flutter pub add magic
dart run magic:artisan magic:install
```

Magic ships its own `artisan` executable, so `dart run magic:artisan` works the moment `magic` is a dependency, with no global activation and no per-app wrapper to write. The one-shot `magic:install` scaffolds every config file, your service providers, the `.env` files, and a ready-to-run `lib/main.dart` bootstrap. The full setup walkthrough, all 18 facades, the CLI generators, and every subsystem live at the [Getting Started guide](https://magic.fluttersdk.com/getting-started/installation).

## Why Magic?

Flutter gives you widgets, but not architecture. Building a real app means wiring up HTTP clients, auth flows, caching, validation, routing, and state management, all from scratch, every time.

**Magic fixes this.** If you know Laravel, you already know Magic:

```dart
// Before: the Flutter way
final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
final response = await dio.get('/users/1');
final user = User.fromJson(response.data['data']);
// ...manually handle tokens, errors, caching, state...

// After: the Magic way
final user = await User.find(1);
```

The same Facades, the same Eloquent syntax, the same Service Provider lifecycle you reach for in Laravel, mapped onto a reactive Flutter client. No `BuildContext` plumbing, no boilerplate.

## Features

| | Feature | Description |
|:--|:--------|:------------|
| 🏗️ | **IoC Container** | Service container with singleton, bind, and instance registration. |
| 🎭 | **18 Facades** | `Auth`, `Http`, `Cache`, `DB`, `Echo`, `Event`, `Gate`, `Log`, `Route`, `Lang`, `Storage`, `Vault`, `Crypt`, and more, static-style access to resolved singletons. |
| 🗄️ | **Eloquent ORM** | Models, query builder, migrations, seeders, factories, a hybrid REST + SQLite persistence layer. |
| 🛣️ | **Routing** | GoRouter integration with middleware, named routes, context-free navigation, and automatic page-title management. |
| 🔐 | **Authentication** | Token-based auth with guards (Bearer, BasicAuth, ApiKey), cache-first session restore, and auto-refresh. |
| 🛡️ | **Authorization** | Gates, policies, and `MagicCan` / `MagicCannot` widgets. |
| ✅ | **Validation** | Laravel-style rules: `Required`, `Email`, `Min`, `Max`, `In`, `Confirmed`, and more. |
| 📡 | **Events** | Pub/sub event system with `MagicEvent` and `MagicListener`. |
| 💾 | **Caching** | Memory and file drivers with TTL and the `remember()` pattern. |
| 🌍 | **Localization** | JSON-based i18n with `:attribute` placeholders. |
| 🎨 | **Wind UI** | Built-in [Wind](https://wind.fluttersdk.com) Tailwind-syntax styling with `className` strings. |
| 📡 | **Broadcasting** | Laravel Echo equivalent: real-time WebSocket channels via the `Echo` facade with presence support and `Echo.fake()`. |
| 🧪 | **Testing** | First-class fakes: `Http.fake()`, `Auth.fake()`, `Cache.fake()`, `Vault.fake()`, `Log.fake()`, `Echo.fake()`. No mockito needed. |
| 🧰 | **Magic CLI** | Artisan-style scaffolding via `dart run magic:artisan make:model`, `make:controller`, and 14 generators. |

## A taste of Magic

A controller fetches over HTTP, an Eloquent model maps the response, and Wind styles the screen, the way it feels in Laravel:

```dart
class UserController extends MagicController with MagicStateMixin<List<User>> {
  static UserController get instance => Magic.findOrPut(UserController.new);

  Future<void> fetchUsers() => fetchList('users', User.fromMap);

  Widget index() => renderState(
    (users) => WDiv(
      className: 'flex flex-col gap-2 p-4 bg-white dark:bg-gray-900',
      children: [
        for (final user in users)
          WText(user.name ?? '', className: 'text-base text-gray-900 dark:text-white'),
      ],
    ),
    onLoading: const CircularProgressIndicator(),
    onError: (msg) => WText('Error: $msg', className: 'text-red-500'),
  );
}
```

```dart
// Eloquent: SQLite-first, API fallback, automatic sync
final user = await User.find(1);
final admins = await User.where('role', 'admin').get();
await user.save();

// Context-free navigation, auth, and validation, from anywhere
MagicRoute.toNamed('user.show', params: {'id': '1'});
if (Auth.check()) { final me = Auth.user<User>(); }
final ok = Validator.make(data, {'email': [Required(), Email()]}).passes();
```

See the [documentation](https://magic.fluttersdk.com) for the full Facade reference, the Eloquent guide, routing, forms, broadcasting, and testing.

## AI Coding Assistants

Magic ships AI-first. The **magic-framework** skill teaches your agent the correct patterns, Facades, Eloquent ORM, Service Providers, controllers, routing, and the common anti-patterns, so it generates correct Magic code on the first try. The skill is distributed through [**fluttersdk/ai**](https://github.com/fluttersdk/ai) for Claude Code, Cursor, OpenCode, Gemini CLI, VS Code Copilot, Codex CLI, Cline, and Roo Code with one command:

```bash
npx skills add fluttersdk/ai --skill magic-framework
```

## Documentation

Full docs at **[magic.fluttersdk.com](https://magic.fluttersdk.com)**.

| Topic | |
|-------|--|
| [Installation](https://magic.fluttersdk.com/getting-started/installation) | Setup and requirements |
| [Configuration](https://magic.fluttersdk.com/getting-started/configuration) | Environment and config files |
| [Service Providers](https://magic.fluttersdk.com/getting-started/service-providers) | Provider lifecycle |
| [Routing](https://magic.fluttersdk.com/basics/routing) | Routes and navigation |
| [Controllers](https://magic.fluttersdk.com/basics/controllers) | Request handlers |
| [HTTP Client](https://magic.fluttersdk.com/basics/http-client) | Network requests |
| [Eloquent ORM](https://magic.fluttersdk.com/eloquent/getting-started) | Models and persistence |
| [Forms](https://magic.fluttersdk.com/basics/forms) | Form handling and validation |
| [Broadcasting](https://magic.fluttersdk.com/digging-deeper/broadcasting) | Real-time WebSocket channels |
| [Magic CLI](https://magic.fluttersdk.com/packages/magic-cli) | Generators and scaffolding |

## Contributing

```bash
git clone https://github.com/fluttersdk/magic.git
cd magic && flutter pub get
flutter test && dart analyze
```

[Report a bug](https://github.com/fluttersdk/magic/issues/new?template=bug_report.yml) · [Request a feature](https://github.com/fluttersdk/magic/issues/new?template=feature_request.yml)

## License

MIT, see [LICENSE](LICENSE) for details.

---

<p align="center">
  <sub>Built with care by <a href="https://github.com/fluttersdk">FlutterSDK</a></sub><br/>
  <sub>If Magic saves you time, <a href="https://github.com/fluttersdk/magic">give it a star</a>, it helps others discover it.</sub>
</p>
