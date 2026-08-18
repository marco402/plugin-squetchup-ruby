 module Auvent
 #Definition of coverage types / Définition des types de couverture
 COVER_TYPES = {
  onduline_transparente: {
    name: "Onduline transparente",        #Transparent Onduline no accent in name / pas d'accent dans name
    material: "EffetTransparent",
    thickness: 20.mm,
    mode: :flat,
    generator: :generate_onduline
  },
  polycarbonate_15mm: {
    name: "Polycarbonate 15mm",           #15mm polycarbonate
    material: "EffetTransparent",
    thickness: 15.mm,
    largeur: 1000.mm,
    mode: :flat,
    generator: :generate_polycarbonate
  },
  fibrociment_rouge: {
    name: "Fibrociment rouge",           #Red fiber cement
    material: "tuiles",
    thickness: 6.mm,
    largeur: 90.mm,
    mode: :flat,
    generator: :generate_fibrociment
  },
  tuiles_romanes: {
    name: "Tuiles romanes",              #Roman tiles
    material: "tuiles",
    thickness: 6.mm,
    largeur: 260.mm,
    mode: :tiles,
    generator: :generate_tuiles_romanes
  },
  tuiles_canal_decoratives: {
    name: "Tuiles canal decoratives",    #Decorative pan tiles
    largeur: 140.mm,
    mode: :tiles,
    generator: :generate_tuiles_canal
  }
}

end