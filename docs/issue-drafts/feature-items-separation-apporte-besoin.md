# [FRONT] Separation items apporte vs besoin

## Objectif
Separer visuellement les items "Ce que j'apporte" et "Ce que j'ai besoin" sur l'evenement.

## Contexte
Le melange actuel rend la lecture confuse entre besoins du createur et propositions des participants.

## Parcours utilisateur
- Point d'entree : page evenement.
- Etapes principales : createur ajoute un besoin; participant ajoute ce qu'il apporte.
- Cas limites : aucune proposition, aucun besoin.

## UI / UX
- Ecrans impactes : detail evenement, creation/edition d'item.
- Composants a creer/modifier : deux sections ou onglets; formulaire avec type d'item.
- Etats (loading, empty, error, success) : empty states distincts.
- Micro-interactions : compteur par section.

## Responsive
- Mobile : sections empilees.
- Tablette : sections empilees ou accordions.
- Desktop : deux colonnes si place.

## Accessibilite
- Navigation clavier : tab order coherent.
- Contrast / lisibilite : titres de section visibles.

## API / Data
- Endpoints utilises : items list/create/update avec item_kind.
- Format des donnees : item_kind (need|bring).
- Cache / pagination : rafraichir sections apres action.

## Analytics / Tracking (si besoin)
- Events : item_create_need, item_create_bring.
- Props : event_id, item_id.

## Tests
- Unitaires : rendu sections avec item_kind.
- Integration : creation item dans la bonne section.
- E2E (si applicable) : parcours createur vs participant.

## Definition of Done
- [ ] UX conforme aux specs
- [ ] Responsive valide
- [ ] Etats limites geres
- [ ] Tests passes
- [ ] Docs mises a jour (si besoin)

## Notes / Risques
Clarifier le wording entre "apporte" et "besoin".
