# Parallèle

Application native SwiftUI pour comparer deux images, annoter leurs différences et exporter une fiche avant/après. Interface en français, Liquid Glass natif, stockage local. Aucun compte, service distant, package tiers ou clé API.

## Versions et historique

Le [journal des modifications](CHANGELOG.md) décrit les nouveautés et les correctifs. La première version publiée est repérée par le tag [`v1.0.0`](https://github.com/rfielbal/iphoneDuo/tree/v1.0.0) ; elle correspond à l’app Xcode 1.0, build 1.

Chaque modification significative terminée est vérifiée, documentée, puis commitée et poussée avec un message en français. Les [consignes du projet](AGENTS.md) décrivent ce fonctionnement. Le détail reste consultable dans l’[historique Git](https://github.com/rfielbal/iphoneDuo/commits/main/).

## Ouvrir et lancer

1. Ouvrir **Parallele.xcodeproj** dans Xcode **27.1 ou plus récent**.
2. Sélectionner le schéma **Parallele** et la destination **Parallèle — iPhone Duo**, sous iOS **27.1**.
3. Lancer avec **⌘R**. Aucun compte développeur n’est nécessaire pour le simulateur.
4. Ouvrir « Une autre lumière », la comparaison de démonstration installée au premier lancement.

Le runtime iOS 27.1 et le simulateur dédié ont été installés sur ce Mac lors de la création du projet. Sur un autre Mac : Xcode > Settings > Components, installer iOS 27.1 ; puis Xcode > Open Developer Tool > Device Hub, bouton + > Simulators, choisir iPhone Duo et iOS 27.1, le nommer « Parallèle — iPhone Duo », puis Create. On peut aussi ouvrir Device Hub via « Manage Devices… » dans le menu de destination. Pour un appareil physique, choisir une équipe dans Signing & Capabilities et un identifiant de bundle disponible.

Version minimum de l’app : iOS 26.0. Le SDK de compilation requis reste 27.1 pour l’adaptation Duo. Sur iOS 26, la comparaison utilise une disposition de repli.

## Utilisation

- **+** : choisir séparément Original et Retouche via le sélecteur Photos, donner un titre, créer. Seules les photos choisies sont accessibles à l’app. Le bouton d’inversion échange les images avant création.
- **Auto** : balayage en largeur compacte ; comparaison des deux images dans une fenêtre large.
- **Balayage** : déplacer le séparateur A/B. Le mode peut être imposé même sur un grand écran.
- **Côte à côte** : présenter les deux images. Sur Duo, `ArrangementView` choisit une répartition adaptée à l’espace et à la séparation de l’écran ; elle peut devenir verticale.
- **Zoom** : pincer pour zoomer de 1× à 4× ; déplacer l’image zoomée avec un doigt. Le bouton de zoom alterne 1× et 2×. La transformation est synchronisée.
- **Bulle +** : toucher un détail de l’image, saisir une observation, enregistrer. Le placement repasse à 1× pour rester précis. Toucher un repère pour relire ou modifier sa note.
- **Options > Annotations** : liste complète ; glisser une note pour la supprimer.
- **Partager** : produire un PNG avec les deux images complètes, les repères et les commentaires. Choisir ensuite Photos, Fichiers ou une autre destination dans la feuille de partage système.
- Appui long sur une carte de la bibliothèque : renommer, dupliquer ou supprimer. La suppression demande confirmation et ne touche pas la photothèque.

Pour importer dans le simulateur, on peut glisser des photos depuis le Finder sur sa fenêtre, puis les choisir dans le sélecteur Photos. Les fichiers DemoBefore.jpg et DemoAfter.jpg peuvent servir d’essai.

## Données et limites

Les projets sont conservés dans `Application Support/Parallele` à l’intérieur du conteneur de l’app : manifeste `projects.json`, copies JPEG dans `Images`. Les images importées sont normalisées (orientation et grand côté maximum 2 500 pixels). Les originaux Photos restent intacts. Sauvegarde du manifeste atomique ; un manifeste illisible est préservé et bloque l’écriture au lieu de réinitialiser les données.

Le titre, les annotations, le mode, le séparateur, le zoom et le déplacement sont sauvegardés. Le redimensionnement conserve le projet et les repères, définis dans les coordonnées normalisées de chaque image. Les images sont ajustées sans recadrage : des marges peuvent apparaître pour des proportions différentes. L’app ne réalise ni retouche, ni recalage automatique de deux prises de vue, ni détection de différences. L’export est une vue d’ensemble, indépendamment du zoom actuel.

Pas de synchronisation iCloud ni de serveur. Désinstaller l’app ou effacer le simulateur supprime son stockage local. Les exports sont indépendants du projet. Une fiche exceptionnellement longue est refusée avec un message au-delà de la limite de taille prévue.

## Tests

**⌘U** exécute les tests unitaires et les parcours UI. Les tests UI utilisent le dossier séparé `Parallele-UITests` et ne réinitialisent pas la bibliothèque normale.

Le parcours d’import nécessite au moins deux photos dans la photothèque du simulateur. Elles ont été ajoutées au simulateur dédié sur ce Mac. Sur un simulateur neuf, le démarrer puis exécuter, depuis le dossier du projet :

```sh
xcrun simctl addmedia booted Parallele/DemoBefore.jpg Parallele/DemoAfter.jpg
```

```sh
xcodebuild -project Parallele.xcodeproj -scheme Parallele \
  -destination 'platform=iOS Simulator,name=Parallèle — iPhone Duo' test
```

Les preuves du passage initial sont décrites dans [Validation.md](Documentation/Validation.md). Le [contrôle du pliage du 21 octobre](Documentation/Validation-pliage-2026-10-21.md) complète ce bilan avec les poses réelles de Device Hub et les mesures de position des repères.

### Rejouer le pliage dans Device Hub

Le test `testAnnotationsSurviveDeviceHubFoldTransitions` demande un pilotage des poses. Il est ignoré lors d’un simple **⌘U**, afin de ne pas attendre une intervention au milieu de la suite ordinaire.

1. Démarrer le simulateur Duo dans Device Hub et choisir **Closed** sous l’appareil.
2. Depuis le dossier du projet, lancer le parcours ci-dessous.
3. Suivre les lignes `[PARALLELE_FOLD] READY_…` du terminal : **Open**, **Closed**, **Open**, puis **Closed**, **Open** et **Partially Open** pour le passage avec zoom.
4. Effectuer chaque changement dans les 120 secondes. Le test attend un changement mesuré de la disposition avant de poursuivre ; une attente dépassée est un échec.

```sh
TEST_RUNNER_PARALLELE_FOLD_TEST=1 xcodebuild \
  -project Parallele.xcodeproj -scheme Parallele \
  -destination 'platform=iOS Simulator,name=Parallèle — iPhone Duo' \
  -only-testing:ParalleleUITests/ParalleleUITests/testAnnotationsSurviveDeviceHubFoldTransitions \
  -parallel-testing-enabled NO \
  -resultBundlePath /tmp/Parallele-pliage.xcresult test
```

Choisir un nouveau chemin `.xcresult` à chaque exécution. Le résultat Xcode contient les captures et les mesures JSON de chaque étape. Les cadres des images ne sont exposés au test qu’en compilation Debug avec `--uitesting`.

Sur le runtime Duo utilisé ici, les captures XCTest de l’écran intérieur peuvent être noires, même si le scénario UI fonctionne. Les captures du bilan ont donc été prises sur l’écran actif avec `simctl` : écran `1` fermé, écran `3` ouvert ou partiellement ouvert. Avec ce seul simulateur démarré, par exemple :

```sh
xcrun simctl io booted screenshot --display 3 /tmp/Parallele-ouvert.png
```

## Organisation

| Fichier | Rôle |
| --- | --- |
| ParalleleApp.swift | Cycle de vie, bibliothèque, présentation de l’éditeur |
| Models.swift | Projet, repère et choix de présentation |
| ProjectStore.swift | Images, persistance, duplication, suppression |
| LibraryView.swift | Bibliothèque, recherche, import Photos |
| ComparisonEditor.swift | Navigation, commandes, notes, sauvegarde, partage |
| ComparisonCanvas.swift | Ajustement des images, balayage, zoom, repères, adaptation Duo |
| ComparisonExporter.swift | Rendu de la fiche PNG |

## Direction visuelle et sources

La maquette validée est conservée dans `Documentation/Direction-Liquid-Glass.png`. Les composants utilisent le matériau système ; son rendu varie avec le contenu, le thème et les réglages d’accessibilité. Les images de démonstration sont des illustrations photographiques générées avec imagegen, pas des photographies documentaires ; elles peuvent présenter de légères variations de géométrie.

- [Liquid Glass : matériaux et lisibilité](https://developer.apple.com/design/human-interface-guidelines/materials)
- [Liquid Glass dans des vues SwiftUI](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)
- [Préparer une app pour iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)
- [Gérer les simulateurs dans Device Hub](https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub)

Le prototype permet d’observer concrètement la séparation contenu/commandes, le redimensionnement, la continuité d’état et les évolutions du SDK. Le projet ne modifie pas automatiquement la veille existante.
