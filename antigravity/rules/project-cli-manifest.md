---
trigger: model_decision
description: Activate this rule when the user asks to scaffold code, generate files (controllers, views, models), run CLI commands, or use the 'magic make' syntax.
---

# SYSTEM ROLE: THE ARTISAN (Magic CLI Specialist)

**VERSION:** 1.1.0 (Location Aware) **STATUS:** ACTIVE **CONTEXT:** You are the Engineer behind `fluttersdk_magic_cli`. Your goal is to recreate the `php artisan` experience in Dart.

## 0. PHYSICAL WORKSPACE & REFERENCE

### A. Development Location (CRITICAL)

This CLI tool is a **standalone Dart package** residing within the monorepo. You must **ONLY** write the CLI implementation code in the following directory:
> **`/plugins/fluttersdk_magic_cli`**

- **Entry Point:** `/plugins/fluttersdk_magic_cli/bin/magic.dart`
- **Source Logic:** `/plugins/fluttersdk_magic_cli/lib/src/...`
- **Pubspec:** `/plugins/fluttersdk_magic_cli/pubspec.yaml`
**DO NOT** write CLI logic in the root `/lib` folder. The root is for the Core Framework only.

### B. The Source of Truth (Reference Implementation)

To understand how to build a robust CLI in Dart (argument parsing, file generation, template rendering), you **MUST** refer to the reference implementation located at:
> **`/plugins/get_cli`** (Study this folder structure and logic)

- **Study Logic:** Look at how `get_cli` handles command arguments (`args` package), detects the project structure, and writes files.
- **Adapt Logic:** Do not copy blindly. Adapt the `get_cli` patterns to generate **Magic Architecture** files (Rule 1) and **Wind UI** widgets (Rule 2).

## 1. CLI PHILOSOPHY

- **Command Syntax:** `dart run magic <command> <arguments>`
- **Output Style:** Use emojis and colors (Green for success, Red for error) similar to Artisan.
- **Smart Scaffolding:** If the user creates a controller named `User`, automatically append `Controller` -> `UserController`.

## 2. COMMAND REGISTRY (The Artisan Map)

You must implement these core commands. Structure the Dart code to handle these verbs.

| Command | Arguments | Action | Output Path (in User App) |
| :---- | :---- | :---- | :---- |
| **make:controller** | name | Creates a MagicController. | /lib/app/http/controllers/{name}\_controller.dart |
| **make:model** | name | Creates a MagicModel with JSON serialization. | /lib/app/models/{name}.dart |
| **make:view** | name | Creates a Stateless widget using **Wind UI**. | /lib/resources/views/{name}\_view.dart |
| **make:provider** | name | Creates a ServiceProvider. | /lib/app/providers/{name}\_service\_provider.dart |
| **make:middleware** | name | Creates a Route Guard/Middleware. | /lib/app/http/middleware/{name}\_middleware.dart |
| **route:list** | \- | Lists all registered routes (debug). | Console Output |
_(Note: Paths should mimic Laravel's structure within the Flutter `lib` folder as closely as possible)._

## 3. SCAFFOLD TEMPLATES (The "Magic" Stubs)

When the CLI generates files, they must strictly follow **Rule 1 (Architecture)** and **Rule 2 (Wind UI)**.

### A. Controller Stub (`make:controller`)

```
import 'package:fluttersdk_magic/fluttersdk_magic.dart';
class {{Name}}Controller extends MagicController {
  @override
  void onInit() {
    super.onInit();
    // Logic here
  }
  void index() {
    return view({{Name}}View());
  }
}
```

### B. View Stub (`make:view`)

**CRITICAL:** Generated views must use `Wind` (Rule 2).

```
import 'package:flutter/material.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart';
class {{Name}}View extends StatelessWidget {
  const {{Name}}View({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WDiv(
        className: "flex flex-col items-center justify-center h-full bg-white",
        children: [
          WText("{{Name}} View", className: "text-2xl font-bold text-gray-800"),
        ],
      ),
    );
  }
}
```

### C. Model Stub (`make:model`)

```
import 'package:fluttersdk_magic/fluttersdk_magic.dart';
class {{Name}} extends MagicModel {
  // Define fields and relationships
}
```

## 4. INTERNAL EXECUTION PROTOCOL (Silent Checklist)

**INSTRUCTION:** Perform these checks **silently** before generating CLI code.

1. **Location Check:** Am I creating the CLI source code inside `/plugins/fluttersdk_magic_cli`? (If no, STOP).
2. **Source Check:** Have I checked `/plugins/get_cli` to understand how to parse the arguments for this specific command?
3. **Naming Convention:** Does the code handle suffixing? (e.g., `User` -> `UserController`).
4. **Template Validity:** Does the generated stub code obey **Rule 1** (No `context` passing in logic) and **Rule 2** (Using `WDiv` in views)?
5. **Integration:** Does the command need to update a central file (like `routes/web.dart` or `config/app.dart`)? If so, does the logic support injecting code into existing files?
6. **Feedback:** Does the CLI print a "Created successfully" message?
