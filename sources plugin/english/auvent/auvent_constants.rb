 module Auvent
 #Definition of coverage types
 COVER_TYPES = {
    transparent_onduline: {
    name: "Transparent Onduline",
    material: "EffetTransparent",
    thickness: 20.mm,
    mode: :flat,
    generator: :generate_onduline
  },
    polycarbonate: {
    name: "polycarbonate",
    material: "EffetTransparent",
    thickness: 15.mm,
    largeur: 1000.mm,
    mode: :flat,
    generator: :generate_polycarbonate
  },
    red_fiber_cement: {
    name: "Red fiber cement",
    material: "tuiles",
    thickness: 6.mm,
    largeur: 90.mm,
    mode: :flat,
    generator: :generate_fibrociment
  },
    roman_tiles: {
    name: "Roman tiles",
    material: "tuiles",
    thickness: 6.mm,
    largeur: 260.mm,
    mode: :tiles,
    generator: :generate_tuiles_romanes
  },
    decorative_canal_tiles: {
    name: "Decorative canal tiles",
    material: "tuiles",
    thickness: 6.mm,
    largeur: 90.mm+50.mm,
    mode: :tiles,
    generator: :generate_tuiles_canal
  }
}
end