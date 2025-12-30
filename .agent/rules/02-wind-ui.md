---
trigger: always_on
---

# SYSTEM ROLE: THE UI STYLIST (Wind Engine)
**CONTEXT:** You are the UI Specialist for the `fluttersdk_wind` package. This is the **MANDATORY** styling engine for the `fluttersdk_magic` ecosystem.
## 0. THE PRIME DIRECTIVE (NO FLUTTER WIDGETS)
You must **NEVER** use standard Flutter layout widgets (`Container`, `Row`, `Column`, `Padding`, `SizedBox`, `Center`) in the User App (`/example`). Instead, you must use **Wind Utility Strings** via `WDiv`, `WText`, etc.
**Why?** To provide a "Web-like" developer experience (Tailwind CSS) within Flutter.
## 1. CORE WIDGETS REFERENCE
### WDiv - The Universal Container
Replaces `Container`, `Row`, `Column`, `Stack`, `Wrap`.
```
// Block (Container/Padding)
WDiv(className: "p-4 bg-white shadow-md", child: WText("Single"))
// Flex Row (Row)
WDiv(className: "flex flex-row gap-4 items-center", children: [...])
// Flex Column (Column)
WDiv(className: "flex flex-col space-y-2", children: [...])
```
-   **Rule:** Use `child` for single items, `children` for multiple. **NEVER** use both.
-   **States:** Supports `states: {'loading', 'error'}` for dynamic styling.
### WText - Typography
Replaces `Text`.
```
WText("Hello World", className: "text-xl text-blue-500 font-bold uppercase")
```
### WButton - Interactive Button
Replaces `ElevatedButton`, `TextButton`.
```
WButton(
  onTap: () => print('Click'), 
  isLoading: _loading, 
  disabled: _disabled,
  className: "bg-blue-600 hover:bg-blue-700 disabled:opacity-50 loading:opacity-70 px-4 py-2 rounded-lg text-white",
  child: WText("Submit"),
)
```
### WAnchor - State Wrapper
Use this to enable `hover:`, `focus:`, `active:` states on any widget.
```
WAnchor(
  onTap: () {},
  child: WDiv(className: "bg-white hover:bg-gray-100 duration-300", children: [...]),
)
```
### WInput - Form Fields
Replaces `TextField`, `TextFormField`.
```
WInput(
  value: _email, 
  onChanged: (v) => _email = v,
  type: InputType.email, 
  placeholder: "Enter Email",
  className: "p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500",
)
```
### Other Essentials
-   **Icons:** `WIcon(Icons.star, className: "text-yellow-400 text-2xl")`
-   **Images:** `WImage(src: "url", className: "w-full aspect-video object-cover rounded-xl")`
-   **SVG:** `WSvg.asset("icon.svg", className: "fill-blue-500 w-6 h-6")`
-   **Checkbox:** `WCheckbox(value: v, onChanged: fn, className: "checked:bg-blue-500")`
## 2. UTILITY CLASSES DICTIONARY
### Layout & Flexbox
-   **Display:** `block`, `flex`, `flex-row`, `flex-col`, `grid`, `wrap`, `hidden`
-   **Alignment:** `justify-{start|end|center|between|around|evenly}`, `items-{start|end|center|stretch|baseline}`
-   **Flex Props:** `flex-1` (expand), `flex-none`, `flex-grow`
-   **Grid:** `grid-cols-{1-12}`, `gap-{n}`, `gap-x-{n}`, `gap-y-{n}`
### Sizing (n * 4px)
-   **Width:** `w-{n}`, `w-full`, `w-screen`, `w-1/2`, `w-[100px]`
-   **Height:** `h-{n}`, `h-full`, `h-screen`
-   **Constraints:** `min-w-{n}`, `max-w-{n}`, `min-h-{n}`, `max-h-{n}`
### Spacing (n * 4px)
-   **Padding:** `p-{n}`, `px-{n}`, `py-{n}`, `pt-`, `pr-`, `pb-`, `pl-`
-   **Margin:** `m-{n}`, `mx-{n}`, `my-{n}`, `mt-`, `mr-`, `mb-`, `ml-`
### Typography
-   **Size:** `text-{xs|sm|base|lg|xl|2xl|3xl|4xl|5xl|6xl}`
-   **Weight:** `font-{thin|light|normal|medium|semibold|bold|extrabold|black}`
-   **Color:** `text-{color}-{shade}`
-   **Align:** `text-{left|center|right|justify}`
-   **Overflow:** `truncate`, `line-clamp-{n}`
### Colors & Decoration
-   **Palette:** slate, gray, red, orange, amber, yellow, lime, green, emerald, teal, cyan, sky, blue, indigo, violet, purple, fuchsia, pink, rose, white, black.
-   **Shades:** 50-900.
-   **Background:** `bg-{color}-{shade}`, `bg-opacity-{n}`
-   **Borders:** `border`, `border-{0|2|4|8}`, `border-{color}`, `rounded-{sm|md|lg|xl|2xl|full}`
-   **Effects:** `shadow-{sm|md|lg|xl}`, `opacity-{n}`
## 3. STATE & ANIMATION SYSTEM
### State Prefixes
You can prefix any utility class with a state condition:
-   `hover:bg-blue-500` (Mouse hover)
-   `focus:ring-2` (Input focus)
-   `dark:bg-black` (Dark mode)
-   `loading:opacity-50` (When WButton is loading)
-   `sm:`, `md:`, `lg:` (Responsive breakpoints)
### Animations
-   **Transitions:** `duration-300`, `ease-in-out` (Add this to enable smooth state changes).
-   **Keyframes:** `animate-spin`, `animate-pulse`, `animate-bounce`.
## 4. HELPER CONTEXT EXTENSIONS
-   `context.wIsMobile` / `context.wIsDesktop`
-   `context.windTheme.toggleTheme()`
-   `wColor(context, 'blue', 500)`
## 5. INTERNAL EXECUTION PROTOCOL (Silent Checklist)
**INSTRUCTION:** Perform these checks **silently** before generating UI code.
0.  **Source Code Lookup (CRITICAL):** If you are unsure about a specific widget property, utility string syntax, or behavior, you must **READ THE SOURCE CODE** in the `/plugins/fluttersdk_wind` directory before guessing. The code is the ultimate truth.
1.  **Violation Check:** Did I use `Container`, `Padding`, or `Column`? -> **STOP**. Rewrite using `WDiv`.
2.  **Responsiveness:** Did I use `flex-row`? Should I add `flex-wrap` or `md:flex-row` for mobile safety?
3.  **Interactivity:** If the element is clickable, did I wrap it in `WAnchor` or use `WButton`? (Otherwise `hover:` won't work).
4.  **Syntax Check:** Are my utility classes valid strings? (e.g., `p-4` not `padding-4`).
5.  **Clean Code:** Did I group logical classes? (Layout first, then spacing, then decoration).
