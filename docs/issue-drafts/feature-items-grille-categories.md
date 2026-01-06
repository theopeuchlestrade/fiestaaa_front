# [FRONT] Grille items + categories + resume quantites

## Objectif
Afficher les items sous forme de grille responsive avec categories simples et resume des quantites.

## Contexte
La liste actuelle est longue. Une grille + filtre par categorie permet de voir rapidement ce que les gens apportent.

## Parcours utilisateur
- Point d'entree : section items sur la page evenement.
- Etapes principales : basculer par categorie, consulter les quantites.
- Cas limites : aucune categorie selectionnee, liste vide.

## UI / UX
- Ecrans impactes : detail evenement.
- Composants a creer/modifier : grille d'items, chips de categorie, bloc resume.
- Etats (loading, empty, error, success) : empty state par categorie.
- Micro-interactions : animation de reflow lors du filtre.

## Responsive
- Mobile : 2 colonnes.
- Tablette : 3 colonnes.
- Desktop : 4+ colonnes selon largeur.

## Accessibilite
- Navigation clavier : navigation sur chips et cards.
- Contrast / lisibilite : tags de categorie lisibles.

## API / Data
- Endpoints utilises : items list (avec category) + summary si dispo.
- Format des donnees : category, quantite, statut.
- Cache / pagination : cache simple, rafraichir apres update.

## Analytics / Tracking (si besoin)
- Events : category_filter_click.
- Props : event_id, category.

## Tests
- Unitaires : rendu grille responsive.
- Integration : filtre categorie.
- E2E (si applicable) : utilisateur filtre et voit le resume.

## Definition of Done
- [ ] UX conforme aux specs
- [ ] Responsive valide
- [ ] Etats limites geres
- [ ] Tests passes
- [ ] Docs mises a jour (si besoin)

## Notes / Risques
Valider les noms de categories (soft/alcool/sale/sucre/autre).
