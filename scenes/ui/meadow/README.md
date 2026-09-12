# Meadow UI kit

Reusable Godot Controls based on the approved cream, sage, and gold restaurant concept. The restaurant prototype now uses this kit. The main menu's older Outpost theme is separate.

## Preview

Run `res://scenes/ui/meadow/showcase.tscn` with F6 for an isolated playground. Switch between service, bottom catalog, and side catalog; try a lower budget and an alternate palette. The Menu example category demonstrates the same card with a recipe instead of furniture. Preview actions do not spend game currency or save progress.

Run `res://scenes/world/meadow_preview.tscn` with F6 to see the components driven by actual restaurant service and building. B opens the shop; cards choose the placement tool. The simulation remains responsible for purchases and placement validation.

## Reusable pieces

| Piece | Reuse |
| --- | --- |
| `item_card.tscn` | A selectable thumbnail card or compact horizontal row, with a typed item resource, price, tooltip, and affordability state. |
| `status_badge.tscn` | Success, warning, and neutral labels. |
| `order_ticket.tscn` | A labeled status card with optional progress. |
| `restaurant_hud.tscn` | A composition of those controls, with bottom/sidebar/automatic catalog arrangements and dynamic categories. |
| `assets/ui/meadow/meadow_theme.tres` | A normal Godot Theme that can be assigned to any Control subtree, including new menus and dialogs. |
| `assets/ui/meadow/default_skin.tres` | Editable color, typography, and spacing tokens used to construct a live Theme. Duplicate it to make a different skin. |

Individual component scenes include the default Theme for convenient standalone use. To inherit a custom parent's theme, clear the component scene's local Theme override. Components instantiated by the HUD inherit its live theme automatically.

## Supply different content

Create resources using `scripts/ui/meadow/item_data.gd`, either as saved `.tres` assets in the Inspector or in code. Fields are id, title, price, category, icon, description, and footprint. Category names are arbitrary. Item resource edits notify existing cards; call `set_items()` again after changing list membership, IDs, or categories.

```gdscript
const ItemData = preload("res://scripts/ui/meadow/item_data.gd")
const ItemCard = preload("res://scenes/ui/meadow/item_card.tscn")

var item := ItemData.new()
item.id = &"daily_special"
item.title = "Garden soup"
item.price = 28
item.category = "Menu"
item.icon = preload("res://assets/ui/meadow/icons/soup.svg")

var card := ItemCard.instantiate()
card.item = item
card.compact = true
$YourContainer.add_child(card)
card.set_state(100, &"daily_special")
card.item_requested.connect(_on_item_requested)
```

Use ordinary VBoxContainer, HBoxContainer, GridContainer, or ScrollContainer parents to arrange cards. Each card has a keyboard focus outline and can be activated with Space/Enter; unaffordable cards are disabled. The card emits an ID and never purchases anything itself.

For the composed HUD, call `set_items(typed_item_array)`, then `set_state({"coins":208, "served":1, "building":false, "open":true, "selected":"dining"})`. Connect `build_toggled` and `item_requested` to the owning screen. `set_orders()` accepts dictionaries with id, title, dish, status, tone, and optional normalized progress; it reuses existing ticket nodes instead of rebuilding them every frame.

## Layout and themes

`catalog_layout` accepts Bottom, Sidebar, or Auto. Sidebar/Auto use a two-column side grid when the logical width is at least 1200; smaller widths use the bottom drawer. Short layouts use horizontal compact cards. Overflow remains accessible through scrollbars and keyboard focus.

When hosting the HUD over an unscaled viewport, call `fit_viewport(viewport_size)` on resize. This adjusts the UI scale and logical size together; both the restaurant and playground demonstrate this. Inside another deliberately scaled UI, size the HUD using its parent containers instead and avoid applying another viewport scale.

Assign a duplicated skin resource to `hud.skin`, then change its palette or font/spacing values. The HUD refreshes its Theme when that resource changes. The static `.tres` Theme used by standalone components is regenerated with `tools/ui/build_meadow_theme.gd` after editing the default skin. Theme variations include PrimaryButton, QuietButton, ItemCard, Heading, Caption, SuccessBadge, WarningBadge, and NeutralBadge.

The restaurant-specific adapter is `scripts/restaurant/restaurant_ui_data.gd`. The reusable components do not import the restaurant model or own customer, placement, or save logic. Furniture thumbnails are rendered from current game assets with `tools/ui/render_thumbnails.gd`; the interface itself uses native Controls rather than stretched concept screenshots.

## Validation

`tests/meadow_ui.gd` checks live orders, card reuse, real mouse/keyboard input, affordability, resource updates, and layout bounds at 1920×1080, 1280×720, 800×600, 640×360, and 900×1200. Run with graphics enabled and `-- --restaurant-test` to avoid user saves. Images and the report are written to `output/restaurant_ui_dynamic/`.

At the smallest resolution the kit scales down to retain all controls; desktop-size windows give the best text readability. These are desktop pointer/keyboard controls, not a separately designed touch interface.
