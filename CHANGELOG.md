# Journal des modifications

Ce journal décrit les évolutions de Parallèle. Les commits conservent le détail des fichiers modifiés ; les tags repèrent les versions publiées.

## À paraître

### 21 octobre 2026

- Correction des commandes de comparaison qui chevauchaient la zone de pliure en position partiellement ouverte : elles restent désormais dans le panneau droit lorsque la division verticale est active.
- Ajout d’un parcours de pliage piloté dans Device Hub : transitions fermé/ouvert, zoom 1× et 2×, position intermédiaire, mesure des deux repères et relecture de leurs notes.
- Conservation des captures et mesures dans le [bilan de pliage](Documentation/Validation-pliage-2026-10-21.md), avec la procédure pour rejouer le test. Le contrôle reste limité au simulateur.

## 1.0.0 — 21 octobre 2026

Première publication du projet sur GitHub, à partir de l’application créée et validée le 20 octobre. Version Xcode : 1.0, build 1.

### Fonctionnalités

- Bibliothèque locale : import de deux photos, recherche, renommage, duplication et suppression des comparaisons.
- Comparaison par balayage ou affichage des deux images, avec zoom et déplacement synchronisés.
- Repères attachés aux images, annotations modifiables et sauvegarde après fermeture de l’application.
- Export d’une fiche PNG contenant les deux images et leurs annotations, via le partage système.
- Interface SwiftUI en français, commandes Liquid Glass et disposition adaptée au Duo.
- Comparaison de démonstration, projet Xcode, tests, documentation et captures de validation inclus.

### Suivi du projet

- Initialisation de l’historique Git sur `main`.
- Ajout de ce journal et des consignes de contribution dans `AGENTS.md`.
- Exclusion des fichiers locaux de Xcode, des compilations et des fichiers de signature.

### Validation et limite connue

Le passage du 20 octobre sous Xcode 27.1 et iOS 27.1 comprend **19 tests réussis, aucun échec et un test ignoré**. Le code publié correspond à cette version ; les tests n’ont pas été rejoués pour la mise en dépôt.

Le test de changement de pose reste non vérifié : la commande de rotation automatisée n’a pas modifié les dimensions de la fenêtre du simulateur. Voir le [bilan de validation](Documentation/Validation.md).

[Version 1.0.0](https://github.com/rfielbal/iphoneDuo/tree/v1.0.0) · [Historique des commits](https://github.com/rfielbal/iphoneDuo/commits/main/)
