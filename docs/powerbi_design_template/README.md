# Power BI Design Template — NYC Taxi Analytics

This directory is a reusable **design reference kit** extracted from the final PBIR state of `urban-mobility-analytics`.

It is intended to accelerate future Power BI dashboards with the same visual language. It is **not** a second report and it does not contain the semantic model, data, credentials, PostgreSQL connection information, DAX model definition, or Power Query logic.

## What is included

- `theme/nyc_taxi_theme.json` — snapshot of the final report theme resource.
- `reference/report.json` — final report-level PBIR definition snapshot.
- `reference/pages.json` — final page-order metadata.
- `reference/<page>/page.json` — final page definition.
- `reference/<page>/visuals/<visual-id>/visual.json` — final PBIR definition for every visual.
- `manifest.json` — export metadata and page inventory.

## Important reuse rule

The files under `reference/` are **technical references, not plug-and-play visual templates**.

`visual.json` files can contain visual IDs, page IDs, query references, table/column names, measures, slicer bindings, navigation destinations and formatting selectors. Those references belong to the source report.

When reusing the design in another dashboard, copy the **design pattern and formatting**, then bind the visual to the new model. Do not blindly paste the files into another PBIR project.

The theme snapshot is substantially more portable than individual visual definitions, although it should still be validated against the target Power BI Desktop version.

# Visual identity

## Concept

The design combines:

1. **NYC taxi identity** — taxi yellow as the principal brand accent.
2. **Urban context** — dark graphite sidebar, asphalt neutrals and concrete-gray canvas.
3. **Analytical semantics** — green for revenue, amber/red for quality and negative conditions.

The goal is a professional urban analytics dashboard, not a decorative taxi-themed interface.

## Core palette

| Role | Hex | Usage |
|---|---|---|
| Taxi Yellow | `#F4C300` | Brand accent, demand lines/bars, active navigation, divider |
| Dark Amber | `#D89B00` | High demand / heatmap maximum |
| Taxi Yellow Dark | `#D8AB00` | Secondary yellow accent |
| NYC Black | `#111318` | Sidebar, strong text |
| Graphite | `#23262D` | Secondary dark surfaces |
| Asphalt Gray | `#5F6672` | Secondary labels and axes |
| Canvas Gray | `#ECEEF1` | Report page background |
| Card White | `#FFFFFF` | KPI/chart/matrix surfaces |
| Border Gray | `#E1E3E7` | Subtle visual borders |
| Revenue Green | `#2F855A` | Revenue and tip emphasis |
| Quality Amber | `#B7791F` | Quality warning metrics |
| Negative Red | `#D64545` | Negative transactions / quality conditions |
| Heatmap Low | `#FFF7CC` | Lowest demand intensity |

## Color semantics

- Executive Overview KPIs: neutral/dark.
- Demand / trip volume: taxi-yellow family.
- Revenue: green.
- Quality warning: amber.
- Negative / suspicious / operational issue conditions: red.
- Neutral categorical analysis: graphite is acceptable.

# Canvas and layout

## Canvas

- Page size: **1920 x 1080**
- Page background: **`#ECEEF1`**
- Do not place one giant background shape behind the report.
- White visual containers sit directly on the gray canvas.
- Desktop grid dots are authoring aids, not part of the consumer view.

## Sidebar

- Width: approximately **320 px**
- Main content starts at approximately **X = 352**
- Sidebar background: **`#111318`**
- Main horizontal gutter: approximately **32 px**

### Branding

- `NYC TAXI`: about **22 pt**, Segoe UI Semibold
- `MOBILITY ANALYTICS`: about **11.5 pt**, Segoe UI Semibold
- Context period such as `JANUARY 2025`: about **10.5 pt**, Segoe UI
- Keep visible left/top padding.

### Navigation

Vertical navigation:

- Overview
- Demand Patterns
- Revenue & Quality

Active state uses taxi yellow with dark text. Inactive state uses graphite/dark surfaces with light text.

In Power BI Desktop authoring mode, page-navigation buttons are tested with **Ctrl + click**.

# Page header

Each page uses:

1. Page title
2. Descriptive subtitle
3. Taxi-yellow divider

Recommended typography:

- Page title: **28–30 pt**, Segoe UI Semibold
- Subtitle: **12–13 pt**, Segoe UI, medium gray

## Divider specification

Final design target:

- X: **352**
- Y: **104**
- Width: **500**
- Visible line weight: **4 px**
- Color: **`#F4C300`**
- Transparency: **0%**
- Horizontal orientation
- No arrows

Power BI may enforce a minimum container height for a line object. Control visible thickness with the line/stroke weight, not by forcing the container below Power BI's minimum height.

# Visual containers

KPI cards, charts and matrix/heatmap share a common surface treatment:

- Background: `#FFFFFF`
- Border: subtle, approximately `#E1E3E7`
- Rounded corners: approximately **10 px**
- Shadow: enabled in the final dashboard to separate white surfaces from the gray canvas
- Keep shadow treatment consistent across pages

The exact final implementation is preserved in the PBIR reference files.

# Typography

| Element | Recommended treatment |
|---|---|
| Page title | Segoe UI Semibold, 28–30 pt |
| Page subtitle | Segoe UI, 12–13 pt |
| Visual title | Segoe UI Semibold, 12–14 pt |
| KPI value | Segoe UI Semibold, 22–28 pt |
| KPI label | Segoe UI, 10–11 pt |
| Sidebar navigation | Segoe UI Semibold, 10–11 pt |
| Sidebar supporting text | Segoe UI / Semibold, 10–12 pt |
| Axis labels | Segoe UI, 9–10 pt |
| Matrix values | Segoe UI, 9–10 pt |
| Matrix headers | Segoe UI Semibold, 9–10 pt |

Avoid making every element Semibold. Font weight should reinforce hierarchy.

# KPI treatment

## Executive Overview

Keep KPI values neutral because they do not represent good/bad states.

Typical row:

- Total Trips
- Net Revenue
- Average Trip Distance
- Average Trip Duration
- Average Speed

`Total Trips` should remain a whole-number measure at model level so matrix values display correctly. If a card needs abbreviated output such as `3.48M`, apply `Display units = Millions` and decimal precision at the **card visual level**, not the measure level.

## Revenue & Quality

- Net Revenue → green
- Total Tips → green
- Average Revenue per Trip → neutral/dark
- Quality Flag Rate → amber
- Negative Transaction Rate → red

# Charts

## Demand

Use taxi yellow for demand/time analysis.

Examples:

- Daily Trip Volume → taxi-yellow line
- Hourly Demand Profile → taxi-yellow line
- Trips by Vendor → taxi yellow
- Trips by Day Period / Day of Week → yellow/amber family

## Revenue

Use revenue green for monetary measures:

- Revenue by Payment Type
- Revenue by Rate Code

## Quality

Use warning/error semantics rather than brand yellow:

- Quality Conditions → red family

## Neutral categorical analysis

Graphite can be used when a chart does not carry positive/negative semantics.

# Demand heatmap

The heatmap represents **intensity**, not good/bad quality. Do not use a red/green diverging scale.

Final approach:

- Format style: Gradient
- Based on: `Total Trips`
- Minimum: Lowest value → `#FFF7CC`
- Maximum: Highest value → `#D89B00`
- **No center / midpoint**
- `Total Trips` displayed as whole numbers
- Values centered
- All 24 hour columns fit without horizontal scrolling
- Row padding adjusted so the matrix uses the container height without a large empty lower area

# Filters and slicers

## Synced global slicers

Synchronize across all three pages:

- Date
- Payment Type
- Vendor

Keep them visible on each page.

## Local slicers

- Day Period → Demand Patterns only
- Rate Code → Revenue & Quality only

Synchronized slicers must bind to the same semantic-model field across pages.

# Reuse workflow

1. Start a new PBIP/PBIR project.
2. Import or reproduce the theme from `theme/nyc_taxi_theme.json`.
3. Recreate the 1920x1080 canvas and 320 px sidebar.
4. Use `reference/` to inspect final layout and formatting patterns.
5. Rebind each visual to the new semantic model.
6. Replace source-specific navigation destinations.
7. Recreate slicer synchronization for the new pages.
8. Validate formatting in the target Power BI Desktop version.
9. Test navigation, filters and interactions.
10. Validate in Power BI Service Reading View before release.

## Do not copy blindly

Do not directly transplant:

- model/table names;
- measure query references;
- filter expressions;
- visual IDs;
- page IDs;
- navigation destinations;
- semantic-model bindings.

# PBIR source snapshot

This kit was generated from the current saved PBIR files.

Pages captured:

- **Executive Overview** — 1920x1080, 18 visual definitions, source page id 895943f24a4d5888a485.
- **Demand Patterns** — 1920x1080, 15 visual definitions, source page id 8b2d29ab28b65bfaf1d5.
- **Revenue & Quality** — 1920x1080, 20 visual definitions, source page id 5f07fa26b2878afa89ca.

The semantic model is intentionally excluded so this package remains a report-design reference.

The theme resource was resolved from the report's `SharedResources` configuration and copied to `theme/nyc_taxi_theme.json`.

# Maintenance

If the source dashboard is intentionally redesigned later, rebuild this directory from the new final PBIR state instead of manually synchronizing every reference file.

Because PBIR schemas can evolve between Power BI Desktop versions, always validate adapted definitions against the target version.
