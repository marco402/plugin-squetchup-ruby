French version after English version.

---------------------------------------------------------------------------------------------------------------------------
   I am sharing this SketchUp plugin, which I developed for my own needs with the help of Copilot.

   It allows you to draw canopies or other assemblies in SketchUp based on a configuration file.

# Menu items (found under the SketchUp Extensions menu)

   - Generate framework from file
   - Generate roofing
   - Generate A4 plan (3 or 4 views)
   - Export A4 plan (JPG)
   - Generate garage roof
   - Export material inventory to console
        - Debug \ Select a line (useful for configuring cutters).
        - Debug \ Display hierarchy in console

   The configuration file describes the components; the filename itself is used to name the generated SketchUp component.

   Roofing generation is separate from framework generation so that A4 plans can be created without the roof.
   A4 plan export is separate from A4 plan generation to allow for the addition of dimensions.
   The "Generate garage roof" function allows you to roof a rectangular building with a single or double pitch oriented along the Y-axis (see special cases).
   To generate A4 plans, search for "cartouche" (title block) in `auvent.rb` if necessary.

# The components are:

     - POTEAU (POST);section x;section y;top;x;y;z;MAT=xxx
     - POUTRE (BEAM);section y;section z;x;y;z;length;y-direction;z-direction;MAT=xxx
     - CHEVRON (RAFTER);number;section x;section y;overhang;MAT=xxx    (automatically placed on the outermost beams)
     - LITEAU (BATTEN);number;section y;section_z;MAT=xxx
     - CLINS (CLADDING);x;y;z;width x;height y;direction;orientation;spacing;thickness;delta_height;Id;MAT=xxx
     - PANNEAU (PANEL);x1;y1;z1;x2;y2;z2;thickness;option;type;MAT=xxx   (option: CAP   type=1:polycarbonate  type=2:solid panel)
     - RIVE (EDGE);section x;section y;MAT=xxx
     - GOUTIERE (GUTTER);diameter;MAT=xxx
     - LAMBRIS (PANELING);x;y;z;width x;height y;direction;orientation;spacing;thickness;delta height;Id;MAT=xxx
     - SOL (FLOOR);section x;section y;height;x;y;z;MAT=xxx

     - XY;section x;section y;x1;y1;z1;x2;y2;z2;option;MAT=xxxdu clins en chêne
     - ANGLE_XZ;section x;section y;x;y;z;length;angle in degrees;MAT=xxxrive de toit
     - ANGLE_YZ;section x;section y;x;y;z;length;angle in degrees;high_point;MAT=xxx       (if x,y,z is the high point: high_point = 1)

For panels that do not touch a rafter or for special cases,
  - the ID of the cutter and the ID of the panel to be processed must match
     - CUTTER;x1;y1;z1;x2;y2;z2;x3;y3;z3;x4;y4;z4;direction;Id(panel to cut) (4 points + 1 direction; removes the part towards the direction; object = siding, paneling...)

# Constraints:
   A minimum of the following is required:
     - 2 beams to support the rafters
     - 2 rafters to support the battens
     - 2 battens to support the roofing (see menu)

# Plugin composition in C:\Users\userNameAppData\Roaming\SketchUp\SketchUp 2017\SketchUp
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

- A default template file
         \Templates
              AuventTemplate.skp

- A style file
         \Styles
              Plan mairie.style

- A template file for using the "Generate garage roof" menu.
         \components\garage_sans_toit.skp

# Special cases
    This code includes specific handling for my awnings; the check is based on the component name.
        These checks take the form: `if(last_component_name=="AUVENT_GARAGE")`
    There are also configuration settings within the code that could easily be moved to the configuration file.
    The `Auvent_garage` involves a special case: unlike the "standard" scenario, the rafters run lengthwise, so they must be named "battens" (liteaux).
        Additionally, the bargeboard is omitted, and the gutter is attached directly to the fiber-cement sheeting.
    The "Generate garage roof" menu allows you to roof a rectangular building with a single- or double-pitch roof oriented along the Y-axis.
        You need to place 2 battens (for a single-pitch roof) or 3 (for a double-pitch roof) to position the roof; if overhangs are required, modify the settings in the code.
        Refer to the `garage_sans_toit.skp` model.

# Test files
    I am attaching my 3 test files.
        The specific features are:
            - 45° brace (abri_voiture.txt)
            - Infill of the resulting triangle using paneling (abri_voiture.txt).
            - Paneling cut to follow the roof slope (abri_voiture.txt).
            - Chamfer and V-groove on the four bottom edges of the beam (abri_voiture.txt).
            - Door with a "gendarme's hat" (curved) top rail (Auvent_garage.txt).
            - Partially open door (Auvent_garage.txt).
            - Cladding panels cut at an angle at the bottom (Auvent_garage.txt).
            - Cladding panels cut at an angle at the top, spaced away from the rafter (Auvent_garage.txt).

# Component
    The awnings are components, allowing them to be integrated into a SketchUp project.
    This allows you to position the awnings initially and then simply update them later.

# SketchUp
    These functions have been tested with SketchUp 2017, available for download here:
    Download SketchUp 2017: https://web.archive.org/web/20220217222923/https://download.sketchup.com/sketchupmake-2017-2-2555-90782-en-x64.exe

# Material
    To add a material:
        - SketchUp materials
        - Right-click and select "Add to model"
        - Select it from the "In Model" list
        - Right-click and select "Save as" to ...\SketchUp\Plugins\auvent\materialsAuvent

---------------------------------------------------------------------------------------------------------------------------
   Je partage ce plugin squetchup que j'ai développé pour mes besoins personnels avec l'aide de copilot.
   
   Il permet de tracer des auvents ou d'autres ensembles dans squetchup à partir d'un fichier de paramétrage.

# Menu affiché dans le menu extension de squetchup

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
   Pour générer les plan A4, rechercher cartouche dans `auvent.rb` si nécessaire.

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
    Il y a également du du paramétrage dans le code qui pourrait-être facilement transféré dans le fichier de paramétrage.
    Auvent_garage contient un cas particulier, contrairemenr au cas "normal", les chevrons sont dans la longueur, dans ce cas il faudra nommer les chevrons liteaux.
        Et la rive est supprimée, la goutière est fixée sur le fibrociment.
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

# composant
     Les auvents sont des composants ce qui permet d'intégrer ces différents auvent à un projet squetchup maison.
       Ce qui permet de positionner ces auvents la première fois et ensuite juste une mise à jour.

# squetchup
     Ces fonctions on étés testées avec squetchup2017 téléchargeable à cette adresse:
               Download squetchup 2017:https://web.archive.org/web/20220217222923/https://download.sketchup.com/sketchupmake-2017-2-2555-90782-en-x64.exe

# materiel
    Pour ajouter un materiel:
        - squetchup materials
        - sélectionner click droit Add to model
        - sélectionner dans la liste In Model
        - click droit  Save as vers ...\SketchUp\Plugins\auvent\materialsAuvent

