# Pliage et annotations — 21 octobre 2026

**Résultat final : 16 tests réussis, aucun échec, aucun test ignoré.** Ce passage comprend les 15 tests unitaires et le nouveau parcours de pliage. Les autres parcours UI d’import, de partage et de redémarrage n’ont pas été rejoués pendant ce contrôle ciblé.

Les deux annotations restent alignées et ouvrables. Le zoom 2× est conservé à la fermeture et à la réouverture. Le mode Auto passe du balayage à la comparaison des deux images. L’écart maximal relevé est de **0,226 point par axe**, inférieur à la tolérance de 2 points.

## Résultats mesurés

| Étape | Fenêtre, en points | Zoom | Écart maximal par axe |
| --- | --- | --- | --- |
| Fermé, départ | 466 × 678 | 1× | 0,000 pt |
| Ouvert | 951 × 669 | 1× | 0,226 pt |
| Refermé | 466 × 678 | 1× | 0,000 pt |
| Rouvert | 951 × 669 | 1× | 0,226 pt |
| Ouvert, agrandi | 951 × 669 | 2× | 0,215 pt |
| Fermé, agrandi | 466 × 678 | 2× | 0,000 pt |
| Rouvert, agrandi | 951 × 669 | 2× | 0,215 pt |
| Partiellement ouvert, agrandi | 951 × 669 | 2× | 0,081 pt |
| Partiellement ouvert, retour à 1× | 951 × 669 | 1× | 0,201 pt |

Chaque étape contrôle les deux repères, leur accès au toucher et le texte de leurs notes. En fin de parcours, les trois commandes sont contenues dans le panneau droit ; le test active puis annule le placement d’une annotation et vérifie que les deux notes existantes sont toujours présentes.

Le passage final correspond à `cycle-03.xcresult`, exécuté de 16 h 08 à 16 h 13, heure de Paris. Un premier essai avait dépassé le délai de pilotage manuel après le dépliage ; il n’a pas été compté comme une réussite. Un deuxième passage complet a réussi, puis le troisième a confirmé les assertions supplémentaires sur le facteur de zoom et les commandes.

## Preuves conservées

- [Bilan brut Xcode](Pliage-2026-10-21/Resultats-tests.json).
- [Mesures des neuf étapes et empreintes des sources testées](Pliage-2026-10-21/Mesures-annotations.json).
- [Écran fermé, deux repères](Pliage-2026-10-21/01-Ferme.png).
- [Écran ouvert, deux repères](Pliage-2026-10-21/02-Ouvert.png).
- [Écran ouvert, zoom 2×](Pliage-2026-10-21/03-Ouvert-zoom.png).
- [Position partiellement ouverte, commandes corrigées](Pliage-2026-10-21/04-Partiellement-ouvert.png).

Les captures publiées proviennent de `simctl` sur l’écran actif : `1` pour l’écran extérieur, `3` pour l’écran intérieur. Les captures XCTest de l’écran intérieur étaient noires sur ce runtime ; elles n’ont pas servi à conclure sur le rendu visuel. Les mesures et assertions proviennent bien du scénario XCTest en cours.

## Environnement et méthode

Contrôle de Parallèle dans **Device Hub**, avec Xcode **27.1 (27A9275)**, le runtime **iOS 27.1** et le simulateur **Parallèle — iPhone Duo**.

Les boutons natifs **Closed**, **Open** et **Partially Open** changent réellement la pose du simulateur. Le scénario XCTest pilote l’application, attend les nouvelles dimensions et mesure les centres des repères dans les cadres des images affichées. Il ne déduit pas un succès de la seule demande de changement de pose.

Deux notes sont créées sur les images de démonstration, dans une bibliothèque de test séparée :

- A : « la courbe de l’escalier reste mon repère » ; position proche de `(0,40 ; 0,41)` dans l’image originale.
- B : « la lumière chaude reste attachée à l’image » ; position proche de `(0,60 ; 0,59)` dans la retouche.

Le test relève leur position normalisée au départ. Après chaque transition, il compare le centre observé de chaque bouton au point attendu dans le nouveau cadre de l’image. La tolérance est de **2 points par axe**, pour tenir compte de l’arrondi des pixels. Il ouvre également chaque note et vérifie son texte exact.

## Correctif découvert pendant le contrôle

En position partiellement ouverte, la barre de commandes initiale restait centrée sur la fenêtre entière. Le bouton d’ajout chevauchait la zone réservée à la pliure. Les photos utilisaient déjà `ArrangementView` ; ce défaut concernait leur barre superposée.

`ComparisonEditor` utilise maintenant les régions réservées déclarées par le système pour garder les commandes dans le panneau droit lorsqu’une division verticale est active. La disposition compacte conserve son centrage. Le déplacement des commandes ne modifie pas les coordonnées enregistrées des annotations.

## Reproduire le contrôle

Le [README](../README.md#rejouer-le-pliage-dans-device-hub) décrit la commande et la séquence des poses. L’activation explicite du scénario évite de bloquer les exécutions ordinaires de la suite. Chaque pose attendue dispose de 120 secondes ; l’absence de changement réel fait échouer le test.

## Portée

Ce contrôle concerne les poses du simulateur, avec deux images de démonstration et deux annotations. Il ne remplace pas une vérification sur iPhone physique, ni une couverture de tous les angles intermédiaires, orientations, tailles de texte et proportions d’images.

Le contrôle antérieur utilisant seulement `XCUIDevice.orientation` reste distinct : cette commande ne redimensionnait pas la fenêtre sur ce runtime. Le présent parcours agit sur les commandes de pliage de Device Hub.

Référence Apple : [Interacting with your app in Device Hub](https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub).
