## Why
Event addresses currently bypass the map chooser on Android and cannot open without stored coordinates. Users need an explicit choice of map provider.

## What Changes
- Always offer a map provider sheet on event address taps.
- Support Google Maps, Waze, OpenStreetMap and Apple Maps on Apple platforms/web.
- Prefer saved coordinates, otherwise search the full address.

## Capabilities
### New Capabilities
None.
### Modified Capabilities
- `navigation`: explicit external map choices.

## Impact
Frontend only; no dependencies, API changes or production deployment.
