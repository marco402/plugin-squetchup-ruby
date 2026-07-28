 module Auvent
 #2 — Définition des types de couverture
 COVER_TYPES = {
  onduline_transparente: {
    name: "Onduline transparente",    #pas d'accent dans le name
    material: "EffetTransparent",
    thickness: 20.mm,
    mode: :flat,
    generator: :generate_onduline
  },
  polycarbonate_15mm: {
    name: "Polycarbonate 15mm",
    material: "EffetTransparent",
    thickness: 15.mm,
	largeur: 1000.mm,              #10mm sinon debordement, revoir le panneau restant sans casser le reste...
	                            #il faudrait regenerer le profil pour le dernier panneau
    mode: :flat,
	generator: :generate_polycarbonate
  },
  fibrociment_rouge: {
    name: "Fibrociment rouge",
    material: "tuiles",
    thickness: 6.mm,
	largeur: 90.mm,
    mode: :flat,
	generator: :generate_fibrociment
  },
  tuiles_romanes: {
    name: "Tuiles romanes",
    material: "tuiles",
	thickness: 6.mm,
	largeur: 260.mm,
    mode: :tiles,
	generator: :generate_tuiles_romanes
  },
  tuiles_canal_decoratives: {
    name: "Tuiles canal decoratives",
    material: "tuiles",
	thickness: 6.mm,
	largeur: 90.mm+50.mm,
    mode: :tiles,
	generator: :generate_tuiles_canal
  }
}
# PARAMS = {

#    poteau: {
#      section: [70.mm, 70.mm],
#      offset_z: 0.mm,
#      rotation: 0.degrees
#    },

#    poutre: {
#      section: [70.mm, 70.mm],
#      offset_z: 0.mm,
#      rotation: 0.degrees
#    },

#    chevron: {
#      section: [35.mm, 70.mm],
#      offset_z: 0.mm,
#      rotation: 0.degrees
#    },

#    liteau: {
#      section: [30.mm, 30.mm],
#      offset_z: 0.mm,
#      rotation: 0.degrees
#    },

#    rive: {
#      section: [22.mm, 200.mm],
#      offset_z: 0.mm,
#      rotation: 90.degrees
#    },

#    faitiere: {
#      section: [45.mm, 45.mm],
#      offset_z: 0.mm,
#      rotation: 45.degrees
#    },

#    tuile: {
#      largeur: 170.mm,
 #     hauteur: 0.mm,
#      recouvrement: 40.mm,
 #     offset_z: 30.mm 
#    }
 # }

end