# Validation du 20 octobre 2026

**Complément du 21 octobre :** le [bilan du pliage dans Device Hub](Validation-pliage-2026-10-21.md) documente les transitions réelles fermé/ouvert et la position intermédiaire. Les résultats ci-dessous restent ceux du passage initial.

**Résultat Xcode : 19 tests réussis, 0 échec, 1 test ignoré explicitement.** Le bilan brut est conservé dans `Resultats-tests.json`.

## Environnement réellement utilisé

- Xcode 27.1, build 27A9275, sur ce Mac.
- SDK et runtime iOS 27.1.
- Simulateur « Parallèle — iPhone Duo », modèle iPhone Duo.
- Projet compilé depuis son emplacement définitif dans `iphoneDuo`.
- Interface française ; deux images de démonstration ajoutées à la photothèque du simulateur pour le parcours d’import.

## Ce que vérifient les tests

Les 15 tests unitaires contrôlent la lecture/écriture des projets, la conservation des annotations et du cadrage, la duplication indépendante, la suppression sans toucher aux fichiers étrangers, la préservation d’un manifeste illisible, la production d’un PNG lisible avec de longues annotations, et les calculs de placement/zoom/déplacement.

Les parcours UI pilotent réellement l’application et les sélecteurs système :

1. Importer deux photos et créer une nouvelle comparaison sans retirer la démonstration.
2. Refuser une création sans titre et sans les deux images ; annuler l’import.
3. Changer les modes, déplacer le séparateur et ouvrir une vraie fiche PNG dans le partage système.
4. Créer une annotation, fermer l’éditeur, le rouvrir, terminer l’application puis relire la note après redémarrage.

Les tests n’envoient aucun fichier à un tiers. Leur bibliothèque séparée ne remplace pas celle utilisée au lancement normal.

## Limite du contrôle des poses

Un cinquième parcours UI demande une rotation, vérifie que la note reste affichée et attend un changement réel des dimensions de la fenêtre. Sur ce runtime Duo, la commande `XCUIDevice.orientation` laisse la fenêtre à 466 × 678 points. Le test est donc explicitement marqué **ignoré**, avec sa raison, au lieu d’annoncer une continuité de format vérifiée.

L’application utilise `ArrangementView` et recalcule ses coordonnées à partir des dimensions disponibles. Les calculs de redimensionnement sont couverts par les tests unitaires. Au terme de ce passage du 20 octobre, **les changements de pose dans Device Hub restaient à vérifier**. Le complément du 21 octobre traite ce point ; la vérification sur appareil physique reste à faire.

Pour cette vérification : ouvrir une comparaison, ajouter un repère sur un détail identifiable, changer la pose dans Device Hub, puis vérifier que le repère reste attaché au même détail, que les deux images restent accessibles et que les commandes ne passent pas sous la séparation de l’écran.

## Portée

La validation concerne le simulateur et les fichiers produits. Elle ne vaut pas certification App Store, test sur matériel physique ou mesure de performances sur une grande photothèque. Les captures fournies sont celles de l’app exécutée ; la maquette de direction artistique est conservée séparément.

## Captures de l’application exécutée

- [Bibliothèque](Captures/01-Bibliotheque.png)
- [Balayage avant/après](Captures/02-Balayage.png)
- [Comparaison des deux images](Captures/03-Comparaison.png)
- [Fiche PNG dans le partage système](Captures/04-Partage.png)
- [Annotation après redémarrage](Captures/05-Annotation-persistante.png)
- [Deux photos importées](Captures/06-Import.png)
- [Projet créé depuis Photos](Captures/07-Projet-importe.png)
