# Wind UI

- [Introduction](#introduction)
- [Core Widgets](#core-widgets)
    - [WDiv](#wdiv)
    - [WText](#wtext)
    - [WButton](#wbutton)
    - [WIcon & WImage](#wicon--wimage)
- [Utility Classes](#utility-classes)
    - [Layout](#layout)
    - [Sizing](#sizing)
    - [Spacing](#spacing)
    - [Typography](#typography)
    - [Colors](#colors)
    - [Borders & Effects](#borders--effects)
- [State Prefixes](#state-prefixes)
- [Form Widgets](#form-widgets)
- [Theme Integration](#theme-integration)
- [Full Documentation](#full-documentation)

<a name="introduction"></a>
## Introduction

Wind UI is Magic's companion UI library that brings Tailwind CSS-like utility classes to Flutter. Instead of using Flutter's `Container`, `Row`, `Column`, and inline styling, you use utility class strings for a web-like developer experience.

```dart
// Before (Flutter)
Container(
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    boxShadow: [BoxShadow(...)],
  ),
  child: Row(children: [...]),
)

// After (Wind UI)
WDiv(
  className: 'p-4 bg-white rounded-lg shadow-md flex flex-row gap-4',
  children: [...],
)
```

<a name="core-widgets"></a>
## Core Widgets

<a name="wdiv"></a>
### WDiv

The universal container widget. Replaces `Container`, `Row`, `Column`, `Stack`, and `Wrap`:

```dart
// Block layout (default)
WDiv(
  className: 'p-4 bg-slate-900 rounded-lg',
  child: WText('Single child'),
)

// Flex row
WDiv(
  className: 'flex flex-row gap-4 items-center',
  children: [Icon1(), Icon2(), Text()],
)

// Flex column
WDiv(
  className: 'flex flex-col gap-2',
  children: [Header(), Content(), Footer()],
)

// Grid
WDiv(
  className: 'grid grid-cols-3 gap-4',
  children: [Card1(), Card2(), Card3()],
)
```

> [!WARNING]
> Never use both `child` and `children` in the same WDiv.

<a name="wtext"></a>
### WText

Typography with utility classes:

```dart
WText('Hello World', className: 'text-2xl font-bold text-white')

WText('Subtitle', className: 'text-sm text-gray-400 uppercase tracking-wide')

WText(
  'Long text that might overflow...',
  className: 'text-base text-gray-700 truncate',
)
```

<a name="wbutton"></a>
### WButton

Interactive button with loading and disabled states:

```dart
WButton(
  onTap: () => controller.submit(),
  isLoading: controller.isLoading,
  disabled: !form.isValid,
  className: '''
    px-4 py-2 bg-primary rounded-lg text-white
    hover:bg-primary/80 disabled:opacity-50 loading:opacity-70
  ''',
  child: WText('Submit'),
)
```

<a name="wicon--wimage"></a>
### WIcon & WImage

```dart
WIcon(Icons.star, className: 'text-yellow-400 text-2xl')

WImage(
  src: 'https://example.com/image.jpg',
  className: 'w-full aspect-video object-cover rounded-xl',
)
```

<a name="utility-classes"></a>
## Utility Classes

<a name="layout"></a>
### Layout

```
flex flex-row flex-col grid wrap hidden
justify-{start|end|center|between|around|evenly}
items-{start|end|center|stretch|baseline}
flex-1 flex-auto flex-none flex-grow flex-shrink
grid-cols-{1-12} gap-{n} gap-x-{n} gap-y-{n}
```

<a name="sizing"></a>
### Sizing

Values are multiples of 4px (e.g., `w-4` = 16px):

```
w-{n} h-{n}           # width/height (n × 4px)
w-full h-full         # 100%
w-screen h-screen     # viewport size
w-1/2 w-1/3 w-2/3     # fractions
w-[100px]             # arbitrary value
min-w-{n} max-w-{n}   # constraints
min-h-{n} max-h-{n}
```

<a name="spacing"></a>
### Spacing

```
p-{n}              # padding all sides
px-{n} py-{n}      # horizontal/vertical padding
pt-{n} pr-{n} pb-{n} pl-{n}  # individual sides

m-{n}              # margin all sides
mx-{n} my-{n}      # horizontal/vertical margin
mt-{n} mr-{n} mb-{n} ml-{n}  # individual sides
mx-auto            # center horizontally
```

<a name="typography"></a>
### Typography

```
text-{xs|sm|base|lg|xl|2xl|3xl|4xl|5xl}
font-{thin|light|normal|medium|semibold|bold|extrabold}
text-{left|center|right|justify}
uppercase lowercase capitalize italic
truncate line-clamp-{n}
```

<a name="colors"></a>
### Colors

**Palette:** slate, gray, zinc, red, orange, amber, yellow, lime, green, emerald, teal, cyan, sky, blue, indigo, violet, purple, fuchsia, pink, rose, white, black, transparent

**Shades:** 50, 100, 200, 300, 400, 500, 600, 700, 800, 900

```dart
// Background
className: 'bg-blue-500'
className: 'bg-slate-900'
className: 'bg-primary'  // Theme color

// Text
className: 'text-white'
className: 'text-gray-400'
className: 'text-red-500'

// With opacity
className: 'bg-blue-500/50'  // 50% opacity
className: 'text-white/80'   // 80% opacity

// Arbitrary hex
className: 'bg-[#FF5733]'
```

<a name="borders--effects"></a>
### Borders & Effects

```
border border-{0|2|4|8}
border-{t|r|b|l}-{n}
border-{color}-{shade}
rounded rounded-{none|sm|md|lg|xl|2xl|full}
shadow-{sm|DEFAULT|md|lg|xl|2xl|none}
ring ring-{0|1|2|4|8} ring-{color}
opacity-{0|25|50|75|100}
```

<a name="state-prefixes"></a>
## State Prefixes

Apply styles conditionally based on widget state:

| Prefix | Trigger | Requires |
|--------|---------|----------|
| `hover:` | Mouse hover | WAnchor/WButton |
| `focus:` | Focus state | WAnchor/WButton |
| `disabled:` | disabled=true | WButton |
| `loading:` | isLoading=true | WButton |
| `checked:` | value=true | WCheckbox |
| `error:` | Validation error | Form widgets |
| `active:` | Custom active state | `states: {'active'}` |
| `sm:` `md:` `lg:` `xl:` | Responsive breakpoints | - |

### Examples

```dart
// Interactive hover state
WAnchor(
  onTap: () => MagicRoute.to('/path'),
  child: WDiv(
    className: 'p-4 bg-white hover:bg-gray-100 duration-300',
    child: WText('Hover me'),
  ),
)

// Button states
WButton(
  isLoading: isLoading,
  disabled: isDisabled,
  className: '''
    bg-primary hover:bg-primary/80 
    disabled:opacity-50 loading:animate-pulse
  ''',
  child: WText('Submit'),
)

// Form validation error
WFormInput(
  className: 'border-gray-300 focus:border-primary error:border-red-500',
  validator: rules([Required()], field: 'email'),
)

// Custom active state
WDiv(
  states: isActive ? {'active'} : null,
  className: 'text-gray-400 active:text-primary active:bg-primary/10',
  child: WText('Tab Item'),
)
```

<a name="form-widgets"></a>
## Form Widgets

See the [Forms documentation](/basics/forms) for detailed form widget usage:

- `WFormInput` - Text inputs with validation
- `WFormCheckbox` - Checkbox with validation
- `WFormSelect` - Dropdown select

<a name="theme-integration"></a>
## Theme Integration

Wind UI integrates with Magic's theming system:

```dart
// Access theme colors
wColor(context, 'primary')
wColor(context, 'blue', shade: 500)
wColor(context, '#FF5733')  // Hex

// Check screen size
wScreenIs(context, 'lg')  // ≥1024px
wScreenIs(context, 'md')  // ≥768px

// Context extensions
context.windTheme          // WindThemeController
context.wIsMobile          // bool
context.wIsDesktop         // bool
context.windIsDark         // bool
```

<a name="full-documentation"></a>
## Full Documentation

This is a summary of Wind UI's capabilities. For complete documentation including all widgets, utility classes, and advanced patterns, see:

**Full Wind UI Documentation:** `/plugins/fluttersdk_wind/docs/`

Topics covered in full documentation:
- Complete utility class reference
- All widget properties and options
- Animation and transition classes
- Custom theme configuration
- Responsive design patterns
- Performance optimization
