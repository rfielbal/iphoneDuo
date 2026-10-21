# Consignes du projet Parallèle

Ces consignes concernent ce dépôt et ses sous-dossiers.

## Modifications et publication

Raphaël a demandé de commiter et de pousser chaque modification significative terminée. Cette autorisation vaut pour les prochaines interventions sur ce projet : une fois les vérifications faites, effectuer le commit et le push sans redemander une confirmation de principe.

- Dépôt : `https://github.com/rfielbal/iphoneDuo.git` ; branche de référence : `main`.
- Avant de modifier le projet, lire l’état Git, la branche active et les différences locales. Préserver le travail en cours de Raphaël.
- Regrouper les changements par objectif cohérent. Ne pas créer un commit pour chaque fichier ou chaque étape provisoire.
- Après une vraie modification, compléter `CHANGELOG.md` avec la date, le changement concret et, si nécessaire, sa limite connue. Les corrections de coquilles isolées peuvent rester dans le seul historique Git.
- Vérifier le diff, les fichiers à inclure et `git diff --check`. Exécuter les contrôles adaptés au changement. Une modification de documentation seule ne demande pas de relancer tous les tests de l’app.
- N’ajouter au commit que les fichiers de l’intervention. Ne jamais publier des secrets, des certificats de signature, des réglages personnels Xcode ou les produits de compilation.
- Effectuer le commit, puis le push vers la branche correspondante sur `origin`. Le flux courant utilise `main` ; respecter une autre branche si une demande ultérieure le prévoit.
- Vérifier que le commit distant correspond au commit local avant d’annoncer la publication. En cas d’échec réseau ou de refus GitHub, conserver le commit local et décrire ce qui reste à pousser.
- Ne pas forcer un push ni réécrire l’historique publié. Si le dépôt distant a avancé, examiner les changements et les intégrer sans écraser le travail existant.

## Messages de commit

Écrire en français naturel, avec accents et ponctuation. Le titre commence par un verbe, décrit le résultat et se termine par un point.

Exemples :

- `Corrige le zoom lors du changement de format.`
- `Ajoute la recherche dans les annotations.`
- `Précise les étapes de lancement dans Xcode.`

Ajouter un corps de message seulement s’il apporte une explication utile ou le résultat des vérifications. Éviter les titres vagues, les emojis, les formulations promotionnelles et les mentions automatiques d’un outil. Ne pas inventer de validation ou d’auteur supplémentaire.

## Historique des versions

- `CHANGELOG.md` contient les évolutions lisibles ; Git conserve le détail exact des changements.
- Inscrire les changements récents dans « À paraître ». Lors d’une nouvelle version identifiée, les regrouper sous son numéro et sa date, puis créer un tag annoté `vX.Y.Z`.
- Utiliser un numéro de correctif pour les corrections, un numéro mineur pour une nouvelle fonctionnalité compatible et un numéro majeur pour une rupture de compatibilité.
- Pour une version de l’app, maintenir `MARKETING_VERSION` et `CURRENT_PROJECT_VERSION` cohérents dans les configurations Debug et Release. Ne pas augmenter la version de l’app pour une simple correction documentaire.
- Le premier tag `v1.0.0` correspond à l’app Xcode `1.0`, build `1`, publiée initialement le 21 octobre 2026. Ne pas fabriquer de commits pour les travaux antérieurs à l’initialisation du dépôt.

## Produit et vérification

Conserver la direction approuvée : photos plein écran, commandes Liquid Glass natives, annotations discrètes et comparaison avant/après. Le projet est une app SwiftUI locale ; son périmètre ne comprend pas le portfolio ni l’automatisation de la veille.

Lire `README.md` pour lancer l’app et ses tests. Distinguer un contrôle statique, un test unitaire, un parcours dans le simulateur et une vérification sur appareil physique. Un test ignoré ne compte pas comme réussi. Le contrôle des poses du Duo doit être signalé comme non vérifié tant qu’un vrai changement de format n’a pas été observé.
