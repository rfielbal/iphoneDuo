# Architecture et décisions

## Une app locale

`ParalleleApp` possède le store observable et la sélection. La bibliothèque ouvre un éditeur plein écran. L’éditeur conserve une copie de travail du projet ; ses changements sont écrits après 350 ms d’inactivité, immédiatement lors d’un enregistrement explicite, à la fermeture et au passage de l’app en arrière-plan.

Le store copie et normalise les images. `projects.json` référence des fichiers relatifs appartenant au conteneur de l’app. Chaque mise à jour du manifeste est atomique. Une erreur de chargement interdit toute écriture plutôt que de reconstruire silencieusement la bibliothèque. Une suppression valide d’abord le nouveau manifeste, puis retire les images devenues inutilisées.

## Comparaison et coordonnées

Le canvas utilise un ajustement proportionnel sans découper les images. Le zoom est commun ; le déplacement est exprimé en fractions de la taille visible. Un repère utilise `(x,y)` entre 0 et 1 dans SON image, indépendamment des dimensions du téléphone. À chaque changement de taille, le rectangle d’image est recalculé. Le balayage masque A à gauche et affiche B à droite ; le choix de l’image à annoter dépend de la position par rapport au séparateur.

Sur SDK27.1, `ArrangementView` gère la disposition des deux images et les régions de séparation. Sur iOS26, un HStack sert de repli. La présentation automatique suit l’espace disponible, pas le nom du matériel. Elle ne prétend pas détecter un angle physique de charnière. Les barres natives peuvent devenir verticales sur Duo ; leurs actions portent un symbole système.

## Liquid Glass

Les commandes personnalisées utilisent `glassEffect` et `GlassEffectContainer`. Les notes utilisent un matériau standard, conformément à la séparation contenu/commandes. Pas de bibliothèque de faux effets de verre. La réduction des animations respecte le réglage système. Les réglages de contraste et de transparence sont pris en charge par les matériaux natifs.

## Export

Le rendu UIKit produit un PNG autonome de 1 800 pixels de large : titre, date, deux images entières, repères et texte des annotations mesuré pour le retour à la ligne. Le document est ensuite transmis à la feuille de partage système ; l’utilisateur choisit explicitement sa destination. Pas de publication automatique.

## Ce qui reste distinct du produit livré

Une version App Store nécessite signature, validation de distribution et contenu éditorial de fiche. Une vérification sur matériel physique reste différente d’un test dans le simulateur. La synchronisation multiappareil, la collaboration, la retouche et le recalage d’images ne sont pas implémentés.
