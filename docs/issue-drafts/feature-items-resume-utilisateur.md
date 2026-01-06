# [FRONT] Resume des items utilisateur

## Objectif
Afficher un resume des items que l'utilisateur doit apporter sur la page evenement (et profil si dispo).

## Contexte
La liste globale d'items est longue; un resume perso evitera la recherche.

## Parcours utilisateur
- Point d'entree : page evenement (section "Mes items").
- Etapes principales : consulter la liste, ouvrir un item si besoin.
- Cas limites : aucun item, utilisateur non participant.

## UI / UX
- Ecrans impactes : detail evenement, profil (optionnel).
- Composants a creer/modifier : liste "Mes items" avec statut/quantite.
- Etats (loading, empty, error, success) : empty state clair.
- Micro-interactions : lien "Voir tous les items".

## Responsive
- Mobile : liste compacte.
- Tablette : section a cote des autres infos.
- Desktop : panneau lateral si possible.

## Accessibilite
- Navigation clavier : navigation liste.
- Contrast / lisibilite : statut lisible.

## API / Data
- Endpoints utilises : GET /events/{id}/my-items (ou my_items dans GET /events/{id}).
- Format des donnees : items + quantite + statut.
- Cache / pagination : cache court, rafraichir apres update.

## Analytics / Tracking (si besoin)
- Events : none.
- Props : none.

## Tests
- Unitaires : rendu liste vide vs pleine.
- Integration : affichage avec data.
- E2E (si applicable) : utilisateur voit ses items.

## Definition of Done
- [ ] UX conforme aux specs
- [ ] Responsive valide
- [ ] Etats limites geres
- [ ] Tests passes
- [ ] Docs mises a jour (si besoin)

## Notes / Risques
Assurer la coherence avec la liste globale.
