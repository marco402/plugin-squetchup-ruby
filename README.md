

   Je partage ce plugin squetchup que j'ai développé pour mes besoins personnels avec l'aide de copilot.
   
   Il permet de tracer des auvents ou d'autres ensembles dans squetchup à partir d'un fichier de paramétrage.
 
# Menu affiché dans le menu extension de  squetchup
 
   - Générer ossature depuis fichier
   - Générer couverture
   - Générer plan A4 (3 ou 4 vues)
   - Exporter plan A4 (JPG)
   - Générer toiture sur garage
   - Exporter l'inventaire du matériel sur la console
        - Debug \ Sélectionner une ligne (utile pour paramétrer les cutters).
        - Debug \ Afficher la Hiérarchie dans la console
   
   Le fichier de paramétrage décrit les composants, le nom du fichier de paramétrage sera utiliser pour nommer le composant squetchup généré.
   
   Générer couverture est séparé de générer ossature pour pouvoir générer les plan A4 sans la couverture.
   L'export plan A4 est séparé de générer les plan A4 pour permettre d'ajouter les cotations.
   Le menu Générer toiture sur garage permet de couvrir un batiment rectangulaire 1 ou 2 pentes orientées sur y (voir cas particuliers).
   Pour générer les plan A4, rechercher cartouche dans auvent.rb si nécessaire.
# Les composant sont:
 
     - POTEAU;section x;section y;sommet;x;y;z;MAT=xxx
     - POUTRE;section y;section z;x;y;z;longueur;direction y;direction z;MAT=xxx
     - CHEVRON;nombre;section x;section y;dépassement,MAT=xxx    (pose automatique sur les poutres extrêmes)
     - LITEAU;nombre;section y;section_z;MAT=xxx
     - CLINS;x;y;z;largeur x;hauteur y;direction;orientation;pas;épaisseur;delta_hauteur;Id;MAT=xxx
     - PANNEAU;x1;y1;z1;x2;y2;z2;épaisseur;option;type;MAT=xxx   (option: CHAPEAU   type=1:polycarbonate  type       =2:panneau plein)
     - RIVE;section x;section y;MAT=xxx
     - GOUTIERE;diamètre;MAT=xxx
     - LAMBRIS;x;y;z;largeur x;hauteur y;direction;orientation;pas;épaisseur;delta hauteur;Id;MAT=xxx
     - SOL;section x;section y;hauteur;x;y;z;MAT=xxx
 
     - XY;section x;section y;x1;y1;z1;x2;y2;z2;option;MAT=xxx
     - ANGLE_XZ;section x;section y;x;y;z;longueur;angle en degrés;MAT=xxx
     - ANGLE_YZ;section x;section y;x;y;z;longueur;angle en degrés;point_haut;MAT=xxx       (si x,y,z est le point haut :point_haut = 1)

Pour les panneaux qui ne tangente pas un chevron ou pour des cas particulier,
  - id entre le cutter et id du panneau à traiter doivent correspondre
     - CUTTER;x1;y1;z1;x2;y2;z2;x3;y3;z3;x4;y4;z4;direction;Id(panneau à couper)  (4 point + 1 direction, supprime la partie vers direction;objet = clin,lambris...)

# Contraintes:
   Il faut au minimum
     - 2 poutres pour poser les chevrons
     - 2 chevrons pour poser les liteaux
     - 2 liteaux pour poser la couverture(voir menu) 


# Composition du plugin dans C:\Users\userNameAppData\Roaming\SketchUp\SketchUp 2017\SketchUp
     \Plugins
          - UI_auvent.rb	
               - auvent\auvent.rb
               - auvent\auvent_constants.rb
               - auvent\utils_auvent.rb
               - auvent\PrintHierarchy.rb
               - auvent\materialsAuvent\
                    - woodAuvent.skm
                    - lambris.skm
                    - EffetTransparent.skm
					- ...

    - Un fichier template par defaut
         \Templates
              AuventTemplate.skp
  
    - Un fichier style
         \Styles
              Plan mairie.style
      
    - Un fichier modèle pour utiliser le menu Générer toiture sur garage.
         \components\garage_sans_toit.skp	  
# Cas particuliers
    Ce code contient des traitements particuliers liés à mes auvents, le test se fait sur le nom du composant.
        Ces tests sont de la forme: if(last_component_name=="AUVENT_GARAGE")
    Il y a également du code de paramétrage qui pourrait-être facilement transféré dans le fichier de paramétrage.
    Le menu Générer toiture sur garage permet de couvrir un batiment rectangulaire 1 ou 2 pentes orientées sur y.
        Il est nécessaire de placer 2(1 pente) ou 3(2 pentes) liteaux pour positionner la toiture, s'il faut des débords, changer le paramétrage dans le code.
        Voir le modèle garage_sans_toit.skp

# Fichiers de test
    Je vous joint mes 3 fichiers pour test.
        Les fonctions spécifiques sont:
            - Jambe de force à 45°(abri_voiture.txt)
            - Remplissage du triangle formé avec des lambris(abri_voiture.txt).
            - Coupe des lambris pour suivre la pente du toit(abri_voiture.txt).
            - Chanfrein et gorge en V sur les 4 cotés du bas de la poutre(abri_voiture.txt).
            - Porte avec un chapeau de gendarme(Auvent_garage.txt).
            - Porte entre-ouverte(Auvent_garage.txt).
            - Panneaux en clins coupé en biais dans le bas(Auvent_garage.txt).
            - Panneaux en clins coupé en biais en haut à distance du chevron(Auvent_garage.txt).

#composant
     Les auvents sont des composants ce qui permet d'intégrer ces différents auvent à un projet squetchup maison.
       Ce qui permet de positionner ces auvents la première fois et ensuite juste une mise à jour.
	   
#squetchup
     Ces fonctions on étés testées avec squetchup2017 téléchargeable à cette adresse:
               Download squetchup 2017:https://web.archive.org/web/20220217222923/https://download.sketchup.com/sketchupmake-2017-2-2555-90782-en-x64.exe
#materiel
    Pour ajouter un materiel:
        - squetchup materials
        - sélectionner click droit Add to model
        - sélectionner dans la liste In Model
        - click droit  Save as vers ...\SketchUp\Plugins\auvent\materialsAuvent

