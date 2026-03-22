# Politique de sécurité

## Versions prises en charge

Les correctifs de sécurité ciblent en priorité :

- la branche `main` ;
- la version web actuellement déployée en production ;
- les chaînes de build et de déploiement décrites dans la documentation d'exploitation du projet.

Les branches anciennes, forks non maintenus ou builds dérivés ne sont pas garantis.

## Signaler une vulnérabilité

Ne créez pas d'issue publique pour signaler une faille de sécurité.

Canal recommandé quand le dépôt sera public :

- GitHub Private Vulnerability Reporting, une fois activé.

Tant que ce mécanisme n'est pas disponible :

- signalez la vulnérabilité au mainteneur via un canal privé déjà établi ;
- demandez explicitement un canal d'échange sécurisé si vous devez transmettre un secret, un PoC sensible ou des journaux contenant des données privées ;
- évitez toute divulgation publique avant validation du correctif.

## Ce qu'il faut inclure dans le signalement

Merci d'inclure, si possible :

- le composant concerné ;
- l'impact attendu ;
- les prérequis d'exploitation ;
- des étapes de reproduction ;
- un PoC minimal si vous en avez un ;
- les versions ou commits concernés.

## Attentes de divulgation

Objectif côté maintenance :

- accuser réception rapidement ;
- confirmer si le problème est bien une vulnérabilité ;
- préparer un correctif ou une mitigation ;
- coordonner la divulgation une fois le risque réduit.

Cette politique doit être utilisée avec la doc de déploiement backend et le runbook de passage en open source quand les dépôts deviendront publics.
