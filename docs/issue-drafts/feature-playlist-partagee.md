# [FRONT] Playlist partagee sur evenement

## Objectif
Afficher et permettre l'edition d'une playlist partagee sur la page evenement.

## Contexte
Les participants ont besoin d'un espace musique commun (Spotify/Apple Music/Deezer).

## Parcours utilisateur
- Point d'entree : page evenement (createur) et page evenement (participant).
- Etapes principales : ajouter lien, sauvegarder, ouvrir la playlist.
- Cas limites : lien invalide, provider inconnu, suppression du lien.

## UI / UX
- Ecrans impactes : detail evenement, edition evenement.
- Composants a creer/modifier : input URL, select/auto-detect provider, bouton "Ouvrir".
- Etats (loading, empty, error, success) : loading save, erreur validation, empty state.
- Micro-interactions : icone provider, toast de confirmation.

## Responsive
- Mobile : champs empiles, bouton en pleine largeur.
- Tablette : layout 2 colonnes si place.
- Desktop : lien + bouton alignes.

## Accessibilite
- Navigation clavier : labels + focus visibles.
- Contrast / lisibilite : message d'erreur lisible.

## API / Data
- Endpoints utilises : GET /events/{id}, PATCH /events/{id}.
- Format des donnees : playlist_url, playlist_provider.
- Cache / pagination : refresh des donnees apres save.

## Analytics / Tracking (si besoin)
- Events : playlist_open, playlist_save.
- Props : event_id, provider.

## Tests
- Unitaires : validation UI URL.
- Integration : sauvegarde + affichage.
- E2E (si applicable) : createur ajoute, participant ouvre.

## Definition of Done
- [ ] UX conforme aux specs
- [ ] Responsive valide
- [ ] Etats limites geres
- [ ] Tests passes
- [ ] Docs mises a jour (si besoin)

## Notes / Risques
Besoin d'une liste claire des providers supportes.
