# [FRONT] Covoiturage par evenement

## Objectif
Ajouter un module covoiturage dans la page evenement (proposer une voiture, rejoindre une voiture).

## Contexte
Besoin recurrent pour organiser les trajets, surtout pour les BDE.

## Parcours utilisateur
- Point d'entree : section "Covoiturage" dans l'evenement.
- Etapes principales : proposer une voiture, rejoindre/quitter, voir places restantes.
- Cas limites : plus de places, voiture supprimee.

## UI / UX
- Ecrans impactes : detail evenement.
- Composants a creer/modifier : carte voiture, formulaire creation, bouton rejoindre/quitter.
- Etats (loading, empty, error, success) : empty state invite a proposer une voiture.
- Micro-interactions : compteur places restantes, confirmation.

## Responsive
- Mobile : cartes empilees, bouton full width.
- Tablette : grille 2 colonnes.
- Desktop : grille 3 colonnes si place.

## Accessibilite
- Navigation clavier : focus sur boutons rejoindre/quitter.
- Contrast / lisibilite : compteur de places lisible.

## API / Data
- Endpoints utilises : liste carpools, create/update/delete, join/leave.
- Format des donnees : seats_total, seats_taken, driver, origin, depart_at.
- Cache / pagination : rafraichir liste apres action.

## Analytics / Tracking (si besoin)
- Events : carpool_create, carpool_join, carpool_leave.
- Props : event_id, carpool_id.

## Tests
- Unitaires : rendu carte + etats.
- Integration : join/leave met a jour l'UI.
- E2E (si applicable) : parcours complet covoiturage.

## Definition of Done
- [ ] UX conforme aux specs
- [ ] Responsive valide
- [ ] Etats limites geres
- [ ] Tests passes
- [ ] Docs mises a jour (si besoin)

## Notes / Risques
Besoin de clarifier si les passagers sont affiches ou seulement le compteur.
