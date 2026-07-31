# Written by Marc Prieur (marco40_github@sfr.fr)
#                                    auvent.rb 
#                               project plugin-squetchup-ruby
#                                 Plugin for Squetchup
# **************************************************************************************
# Creative Commons Attrib Share-Alike License
# You are free to use/extend this library but please abide with the CC-BY-SA license:
# Attribution-NonCommercial-ShareAlike 4.0 International License
# http://creativecommons.org/licenses/by-nc-sa/4.0/

# All text above must be included in any redistribution.
#  **********************************************************************************
#Déposer ce fichier dans :
#C:\Users\...\AppData\Roaming\SketchUp\SketchUp xxx\SketchUp\Plugins\
#Relancer SketchUp
#Extensions → Auvent

module Auvent
	module FctAuvent

		@materials = {}
		@last_component_name = nil   # mémorise le nom du composant généré

		#************************Instances-Definition-Composant************************************

		def self.place_instance(definition)
			tr = Geom::Transformation.new([0,0,0])
			Sketchup.active_model.active_entities.add_instance(definition, tr)
		  end

		def self.get_or_create_definition(name)
			defs = Sketchup.active_model.definitions
			defs[name] || defs.add(name)
		end

		def self.clear_definition(definition)
			begin
			  definition.entities.clear!
			rescue
			  # fallback SU2017
			  definition.entities.to_a.each(&:erase!)
			end
		end

		def self.last_component_name
			@last_component_name
		end

		def self.last_component_name=(name)
			@last_component_name = name
		end

		#*********************************Principales fonctions**************************************

		def self.generer_ossature_depuis_fichier(path, comp_name)
		  FctAuvent.materials.merge!(load_all_materials_from("materialsAuvent"))
		  model = Sketchup.active_model
		  puts "=== generer_ossature_depuis_fichier(#{path}, #{comp_name}) ==="
		  model.start_operation("Génération Auvent", true)
		  auvent_def = get_or_create_definition(comp_name)
		  puts "def trouvé/créé : #{auvent_def} (instances: #{auvent_def.instances.length})"
		  inst = auvent_def.instances.first
		  tr = inst ? inst.transformation.clone : nil
		  puts "inst existante ? #{!inst.nil?} / tr=#{tr.inspect}"
		  clear_definition(auvent_def)
		  puts "def nettoyée (entities: #{auvent_def.entities.length})"

		  FctAuvent.materials.merge!(load_all_materials_from("materialsAuvent"))

		  generer_ossature(auvent_def.entities, path)
		  if tr
			inst = auvent_def.instances.first
			inst.transformation = tr if inst
		  else
			place_instance(auvent_def)
		  end

		  model.commit_operation
		end

		def self.generer_ossature( ents,path)
		  data = lire_fichier_ossature(path)
		  pieces = data[:pieces]
		  root = ents.add_group
		  root.name = "Ossature Auto"
		  model = Sketchup.active_model
		  # --- Layer Auvent ---
		  layer_auvent = model.layers["Auvent"]
		  layer_auvent = model.layers.add("Auvent") unless layer_auvent

		  # --- Layer Projection (pour les vues 2D) ---
		  layer_projection = model.layers["Projection"]
		  layer_projection = model.layers.add("Projection") unless layer_projection

		  # --- Mettre l'auvent dans ce layer ---
		  root.layer = layer_auvent 

		  # --- Création des pièces ---
		  pieces.each do |p|
			type = p[0]
			dispatch_type_piece(root, p,layer_auvent)
		  end

		end

		def self.dispatch_type_piece(root, p,layer_auvent)
		  type = p[0]
		  case type
		  when "POTEAU"
			piece_verticale(root, p)
		  when "POUTRE"
			piece_direction(root, p)
		  when "SOL"
			piece_verticale(root, p)
		  when "PENTE"
			piece_pente(root, p)
		  when "ANGLE_XZ"
			piece_angle_xz(root, p)
		  when "ANGLE_YZ"
			piece_angle_yz(root, p)
		  when "CHEVRON"
			generate_chevrons_sur_poutres(root,p[1],[p[3],p[2]],p[4],p[5])
		  when "LITEAU"
			generate_liteaux_sur_chevrons(root,p[1],[p[3],p[2]],p[4])
		  when "RIVES"
			generer_rives(root, layer_auvent,p)
		  when "GOUTIERE" 
			generer_gouttieres(root, layer_auvent,p) 
		  when "LAMBRIS"  
			piece_panneau_lambris(root, p) 
		  when "CLINS"
			piece_panneau_clins(root, p) 
		  when "PANNEAU"
			piece_panneau(root, p) 
		  when "XY"
			g=piece_xy(root, p)
			case p[9]
			  when 1
				face_ext = g.entities.grep(Sketchup::Face).find { |f|
				f.normal.samedirection?(Geom::Vector3d.new(0,0,1))
				}
				chanfrein_rect_horizontal_su2017( face_ext, 10.mm, 10.mm)
			  end
			g.material=p[-1]
		  when "RENFORT_45"
			piece_renfort_45(root, p) 
		  when "CUTTER"
			piece_panneau_cutter(root, p)
		  else
			puts "Type inconnu : #{type}"
		  end
		end


#generate_couverture traite les cas suivant:
#	pour les auvents:minimum 2 liteaux orientés sur X , la couverture ira de y mini a y maxi des liteaux
# 	cas particulier du garage (voir menu)
#		2 liteaux 1 pente ( commenter l'indice 1 du menu) ou 3 liteaux 2 pentes(indice 0 et 1)
		def self.generate_couverture(cover_type_key, root,garage=nil,option=0)
			cover_type_key = cover_type_key.to_s.downcase.gsub(" ", "_").to_sym
			type = COVER_TYPES[cover_type_key]
			largeur=type[:largeur].inspect
			# --- Débords toit par rapport aux liteaux haut et bas---
			if(last_component_name=="AUVENT_GARAGE")
				debords = {
					gauche: 130.mm,  # gauche (X-)
					droite: 130.mm,  # droite (X+)
					haut: 0.mm,      # haut (vers liteau haut)
					bas: 230.mm      # bas (vers liteau bas)
				}	
			elsif(last_component_name==nil)		#menu Générer toiture sur garage
				tr = garage.transformation
				garage.transformation = IDENTITY
				garage.definition.entities.transform_entities(tr, garage.definition.entities.to_a)			
				FctAuvent.materials.merge!(load_all_materials_from("materialsAuvent"))
				debords = {
					gauche: -175.mm,
					droite: -175.mm, 
					haut: 0.mm, 
					bas: 0.mm
				}	 
			else
				debords = {
					gauche: 0.mm,
					droite: 0.mm,
					haut: 0.mm,
					bas: 50.mm
				}
			end
			# --- Sélection des liteaux ---
			liteaux = root.entities.grep(Sketchup::Group).select { |g| g.name == "LITEAU" }   #classement: Est  Ouest   Milieu
			if liteaux.length < 2
				puts("abandon,nb liteaux < 2 #{liteaux.length}")
				return 
			end
			# --- Conversion locale → globale ---
			to_global = lambda { |group, pt| pt.transform(UtilsAuvent.safe_transformation(group)) }
			# --- Face top = face dont le Z moyen global est le plus haut ---
			top_face = lambda do |group|
				faces = group.entities.grep(Sketchup::Face)
				faces.max_by do |f|
					verts = f.vertices.map { |v| to_global.call(group, v.position) }
					verts.map(&:z).inject(0, :+) / verts.length.to_f
				end
			end
			# --- Arêtes top d’un liteau ---
			top_edges = lambda do |group|
				f = top_face.call(group)
				f ? f.edges : []
			end
			# 1 - ordonner les 3 liteaux suivant Y Min EST et Y MAX OUEST 
			liteaux_sorted = liteaux.sort_by { |g| g.bounds.max.y }
			if(last_component_name==nil)   #menu Générer toiture sur garage
				liteau_haut = liteaux_sorted[1]	
				if(option == 0)		#EST
					liteau_bas  = liteaux_sorted.first
				else				#OUEST
					liteau_bas  = liteaux_sorted.last
				end
			else
				liteau_bas  = liteaux_sorted.first
				liteau_haut = liteaux_sorted.last
			end
			
			# 2 - EST------------------->YMIN des ZMAX
			# 3 - MILIEU pour EST----->  Z MAX et Y < EST
			# 4 - MILIEU pour OUEST--->  Z MAX et Y > OUEST
			# 5 - OUEST----------------->YMAX des ZMAX
			# --- Arêtes top du liteau bas (filtrées par longueur) ---
			edges_bas = top_edges.call(liteau_bas)
			#retourne un tableau de toutes les arêtes > 100
			long_edges_bas = edges_bas.select do |e|
				p1 = to_global.call(liteau_bas, e.start.position)
				p2 = to_global.call(liteau_bas, e.end.position)
				len = p1.distance(p2)
				len > 30.cm			#rejette les edges de la section
			end		
			# --- Arêtes top du liteau haut (filtrées par longueur) ---
			edges_haut = top_edges.call(liteau_haut)
			#retourne un tableau de toutes les arêtes > 100
			long_edges_haut = edges_haut.select do |e|
				p1 = to_global.call(liteau_haut, e.start.position)
				p2 = to_global.call(liteau_haut, e.end.position)
				len = p1.distance(p2)
				len > 30.cm			#rejette les edges de la section
			end
			if(last_component_name==nil)   #menu Générer toiture sur garage
				if(option == 0)		#EST
									#pour liteau bas:EST dans long_edges_bas prendre YMIN
									e_bas=UtilsAuvent.edge_with_lowest_y(long_edges_bas)
									#pour liteau haut  dans long_edges_haut prendre Y<
									e_haut=UtilsAuvent.edge_with_lowest_y(long_edges_haut)
				else				#OUEST
									#pour liteau bas:OUEST  dans long_edges_bas prendre YMAX
									e_bas=UtilsAuvent.edge_with_highest_y(long_edges_bas)
									#pour liteau haut: dans long_edges_haut prendre Y> 
									e_haut=UtilsAuvent.edge_with_highest_y(long_edges_haut)
				end
			else
				e_bas=UtilsAuvent.edge_with_lowest_y(long_edges_bas)
				e_haut=UtilsAuvent.edge_with_highest_y(long_edges_haut)
			end			
			# --- Points en GLOBAL ---
			p1 = to_global.call(liteau_bas,  e_bas.start.position)
			p2 = to_global.call(liteau_bas,  e_bas.end.position)
			p3 = to_global.call(liteau_haut, e_haut.end.position)
			p4 = to_global.call(liteau_haut, e_haut.start.position)
			# --- Application des débords ---
			# Axe X = largeur (liteaux parallèles à X)
			# Axe Y = pente (chevrons parallèles à Y)
			pts = [p1, p2, p3, p4].uniq
			face = root.entities.add_face(pts)			
			if (option==1)
				pts = [p4, p3, p2, p1].uniq
			end
			return if pts.length < 3
			pts=debord_toit_fct_liteaux(pts,debords: debords)
			face = root.entities.add_face(pts)
			generate_couverture_suite(cover_type_key, root,pts ,last_component_name) 
		end

		def self.generate_couverture_suite(cover_type_key, root,pts,last_component_name)
			cover_type_key = cover_type_key.to_s.downcase.gsub(" ", "_").to_sym
			type = COVER_TYPES[cover_type_key]
			return unless type
			# Si un générateur spécifique est défini → on l'appelle
			if type[:generator].is_a?(Symbol) && respond_to?(type[:generator], true)
				largeur = type[:largeur] 
				thickness = type[:thickness]          # Longueur SketchUp en pouces
				thickness_mm = thickness.to_mm        # conversion propre en mm
				thickness_i = thickness_mm.round
				material= type[:material] 
				return send(type[:generator], root, pts, thickness,material,largeur,last_component_name) 
			end
			#  Sinon fallback selon :mode
			case type[:mode]
				when :flat
					generate_couverture_plate(gents,face ,mat ,type_key )
				when :tiles
					generate_couverture_tuiles(gents, face,mat ,type_key )
			else
				puts "⚠️ Type de couverture inconnu : #{cover_type_key}"
			end
		end

		def self.generate_couverture_tuiles(gents, face, mat, type_key)
			return unless face.is_a?(Sketchup::Face)
			# --- Récupération des arêtes de la face ---
			edges = face.edges
			pts = edges.map { |e| e.start.position }.uniq
			if pts.length < 3
				UI.messagebox("Impossible de générer les tuiles : face invalide.")
				return
			end
			# --- Détermination du sens d'extrusion ---
			# On extrude vers le bas (Z négatif)
			thickness = 30.mm  # épaisseur visuelle des tuiles
			# --- Extrusion ---
			begin
				face.pushpull(thickness)
				edge.erase! if edge.valid?	
			rescue
				UI.messagebox("Erreur lors de l'extrusion des tuiles.")
				return
			end
			return face
		end

		#*********************************Profils**************************************

		def self.profil_polycarbonate_15mm_epais(ep, largeur)
			pts_int = [
				Geom::Point3d.new(0,        0, 0),
				Geom::Point3d.new(largeur,  0, 0)
			]
			pts_ext = [
				Geom::Point3d.new(0,            0, ep),
				Geom::Point3d.new(largeur+0.1.mm, 0, ep)
			]
			pts_ext + pts_int.reverse
		end
		
		def self.profil_renfort_45(root,p)
			#generation d'un profil à 45° en xz
			#calcul des 4 points a partir de l'axe
			sxy = p[1]
			sz = p[2]
			x1  = p[3]
			y1  = p[4]
			z1  = p[5]
			x2  = p[6]
			y2  = p[7]
			z2  = p[8]
			diag=(sz/2)*Math.sqrt(2)
			material_name=p[9]
				pts_monde = [
					Geom::Point3d.new(x1-diag,y1-sxy/2,z1),
					Geom::Point3d.new(x1+diag,y1-sxy/2,z1),
					Geom::Point3d.new(x2,y2-sxy/2,z2+diag),
					Geom::Point3d.new(x2,y2-sxy/2,z2-diag),
				] 
			group = root.entities.add_group
			group.name=p[0]
			group.layer = root.layer
			gents = group.entities
			face = gents.add_face(pts_monde)
			face.pushpull(sxy)
			apply_material(gents,material_name)  
		end

		def self.profil_fibrociment_epais(ep , largeur, h, nondes)
			steps = 20   #48  problème de pile(stack) si + 
			pts_ext = []
			pts_int = []
			steps.times do |i|
				t = i.to_f / (steps - 1)
				x = t * largeur
				# Onde complète : monte puis redescend
				z = (1 - Math.cos(2 * Math::PI * t)) * (h / 2)
				pts_ext << Geom::Point3d.new(x, 0, z + ep)
			end
			pts_ext.each { |p| pts_int << Geom::Point3d.new(p.x+0.1.mm, 0, p.z + ep) }
			return pts_ext + pts_int.reverse
		end

		def self.profil_onduline_epais(ep)
			h = 20.mm
			flat_before = 15.mm
			b1   = 7.5.mm
			top  = 25.mm
			b2   = 7.5.mm
			flat_after = 15.mm
			# Largeur totale de l’onde
			largeur_totale = flat_before + b1 + top + b2 + flat_after
			pts_ext = []
			pts_int = []
			# Décalage anti-croisement
			x = 0.1.mm
			# --- Peau extérieure (profil nu) ---
			pts_ext << Geom::Point3d.new(x, 0, 0)
			x += flat_before
			pts_ext << Geom::Point3d.new(x, 0, 0)
			x += b1
			pts_ext << Geom::Point3d.new(x, 0, h)
			x += top
			pts_ext << Geom::Point3d.new(x, 0, h)
			x += b2
			pts_ext << Geom::Point3d.new(x, 0, 0)
			x += flat_after
			pts_ext << Geom::Point3d.new(x, 0, 0)
			# --- Peau intérieure (épaisseur en +Z local + décalage X) ---
			pts_int = pts_ext.map { |p| Geom::Point3d.new(p.x + 0.1.mm, p.y, p.z + ep) }
			# --- Profil épais fermé ---
			profil_epais = pts_ext + pts_int.reverse
			return profil_epais, largeur_totale
		end

		def self.profil_tuiles_canal_epais(ep, largeur, angle, segments)
			rayon_int = (largeur-50.mm) / 2.0
			rayon_ext = rayon_int + ep
			pts_int = []
			pts_ext = []
			x=0
			z=0
			(0..segments).each do |i|
				a = -angle/2 + angle * i.to_f / segments
				z = Math.cos(a) * rayon_int + rayon_int
				x = Math.sin(a) * rayon_int
				pts_int << Geom::Point3d.new(x, 0, z)
			end
			pts_int << Geom::Point3d.new(x+50.mm, 0, z)
			(0..segments).each do |i|
				a = -angle/2 + angle * i.to_f / segments
				z = Math.cos(a) * rayon_ext + rayon_int
				x = Math.sin(a) * rayon_ext
				pts_ext << Geom::Point3d.new(x, 0, z)
			end
			pts_ext << Geom::Point3d.new(x+50.mm, 0, z)
			pts_ext + pts_int.reverse
		end

		def self.profil_tuiles_romanes_epais(ep, plat, galbe, h, segments)
			pts_int = []
			pts_ext = []
			# Plat
			pts_int << Geom::Point3d.new(0,      0, 0)
			pts_int << Geom::Point3d.new(plat,   0, 0)
			# Galbe
			rayon = (galbe**2 + h**2) / (2*h)
			centre_x = plat + (rayon - h)
			(0..segments).each do |i|
				a = Math::PI - Math::PI * i.to_f / segments
				x = centre_x + Math.cos(a) * rayon
				z = Math.sin(a) * rayon
				pts_int << Geom::Point3d.new(x, 0, z)
			end
			pts_int.each { |p| pts_ext << Geom::Point3d.new(p.x, 0, p.z + ep) }
			pts_ext + pts_int.reverse
		end

		#*********************************Plans 2D**************************************

		def self.generate_2d_views_layout
			model = Sketchup.active_model
			layer_projection = model.layers["Projection"]
			# Génère d'abord Face + Gauche
			generate_2d_views
			# Récupération des groupes créés
			face = model.entities.grep(Sketchup::Group).find { |g| g.name == "Vue 2D — Face" }
			left = model.entities.grep(Sketchup::Group).find { |g| g.name == "Vue 2D — Gauche" }
			grp = model.selection.grep(Sketchup::Group).first
			edges = UtilsAuvent.collect_edges_with_transform(grp)
			# --- Vue de dessus (projection XY) ---
			grp_top = model.entities.add_group
			grp_top.layer = layer_projection
			grp_top.name  = "Vue 2D — Dessus"
			edges.each do |p1, p2|
				grp_top.entities.add_line(
					Geom::Point3d.new(p1.x, p1.y, 0),
					Geom::Point3d.new(p2.x, p2.y, 0)
				)
			end
			# --- Alignement automatique ---
			bbox_face = face.bounds
			bbox_left = left.bounds
				bbox_top  = grp_top.bounds
			# Gauche à droite de Face
			dx = bbox_face.width + 200.mm
			left.transform!(Geom::Transformation.new([dx, 0, 0]))
			# Dessus sous Face
			dy = -(bbox_face.height + 200.mm)
			grp_top.transform!(Geom::Transformation.new([0, dy, 0]))
			UI.messagebox("Plan d’urbanisme 2D généré (Face + Gauche + Dessus).")
		end

		def self.export_plan_a4_optimise
			model = Sketchup.active_model
			view  = model.active_view
			# Vérifier qu’un auvent existe
			comp_name = FctAuvent.last_component_name
			return UI.messagebox("Aucun auvent généré.") if comp_name.nil?
			inst = model.active_entities.grep(Sketchup::ComponentInstance)
			.find { |i| i.definition.name == comp_name }
			return UI.messagebox("Aucune instance du composant '#{comp_name}'.") if inst.nil?
			# Appliquer style Plan mairie
			UtilsAuvent.apply_style
			view.refresh
			# Vue TOP + orthographique
			Sketchup.send_action("viewTop:")
			view.camera.perspective = false
			# Layers : n’afficher que la projection
			model.layers.each { |l| l.visible = false }
			layer_proj = model.layers["Projection"]
			layer_proj.visible = true if layer_proj
			# Zoom sur la projection
			view.zoom_extents
			view.refresh
			# Export PNG optimisé SU2017 (noir profond)
			filename = File.join(
				Dir.home,
				"Plan_A4_#{comp_name}_#{Time.now.strftime("%Y-%m-%d_%H%M")}.jpg"
			)
			# Résolution optimisée SU2017
			width  = 1200   # ou 1400
			height = 800    # ou 900
			view.write_image(
				:filename => filename,
				:width    => width,
				:height   => height,
				:antialias => false
			)
			UI.messagebox("Export A4 optimisé terminé.\n\nFichier : #{filename}")
		end

		def self.generate_2d_views_from(entity)
			model = Sketchup.active_model
			defs  = model.definitions
			#  Récupération des entités et de la transformation globale ---
			if entity.is_a?(Sketchup::Group)
				ents = entity.entities
				tr_entity = entity.transformation
			elsif entity.is_a?(Sketchup::ComponentInstance)
				ents = entity.definition.entities
				tr_entity = entity.transformation
			else
				puts "ERREUR: entity n'est ni Group ni Instance"
				return
			end
			# Collecte récursive des faces ---
			faces = UtilsAuvent.collect_all_faces(entity)
			#  Création des définitions 2D ---
			def_face   = defs.add("VIEW_FACE_#{entity.entityID}")
			def_gauche = defs.add("VIEW_GAUCHE_#{entity.entityID}")
			def_dessus = defs.add("VIEW_DESSUS_#{entity.entityID}")
			if(last_component_name=="AUVENT_GARAGE")
				def_droite = defs.add("VIEW_DROITE_#{entity.entityID}")
			end
			# Construction du repère local basé sur les chevrons ---
			chevrons = ents.grep(Sketchup::Group).select { |g| g.name == "CHEVRON" }
			if chevrons.empty?
				u = Geom::Vector3d.new(1, 0, 0)
			else
				edge = UtilsAuvent.long_edge_of(chevrons.first)
				p1 = edge.start.position.transform(tr_entity)
				p2 = edge.end.position.transform(tr_entity)
				dir = p2 - p1
				dir.z = 0
				dir.length = 1.0
				u = dir
			end
			v = Geom::Vector3d.new(-u.y, u.x, 0)
			v.length = 1.0
			#  Projection de chaque face ---
			faces.each do |face|
				tr_global = UtilsAuvent.global_transformation_for_face(face)
				m = tr_global.to_a
				4.times do |i|
					row = m[i*4, 4]
				end
				pts_world = face.vertices.map { |v| v.position.transform(tr_global) }
				coords = pts_world.map { |p|
					pv = Geom::Vector3d.new(p.x, p.y, p.z)
					[pv.dot(u), pv.dot(v), p.z]
				}
				pts_face   = coords.map { |cx, cy, cz| Geom::Point3d.new(0,  cx, cz) }
				pts_gauche = coords.map { |cx, cy, cz| Geom::Point3d.new(0,  cy, cz) }
				pts_dessus = coords.map { |cx, cy, cz| Geom::Point3d.new(cx, cy, 0) }
				if(last_component_name=="AUVENT_GARAGE")
					pts_droite_arriere_plan = coords
					.map { |cx, cy, cz| Geom::Point3d.new(cx, cy, cz) }
					.select { |p| p.x > 1.3}   #1.5 1.4 cadre porte   1.3 ok
					.map { |p| Geom::Point3d.new(0, p.y, p.z) }
					
					pts_droite = coords
					.map { |cx, cy, cz| Geom::Point3d.new(cx, cy, cz) }
					.select { |p| p.x <= 1.3}   
					.map { |p| Geom::Point3d.new(0, p.y, p.z) }
				end
				UtilsAuvent.add_face_to_definition(def_face,   pts_face)
				UtilsAuvent.add_face_to_definition(def_gauche, pts_gauche)
				UtilsAuvent.add_face_to_definition(def_dessus, pts_dessus)
				if(last_component_name=="AUVENT_GARAGE")
					UtilsAuvent.add_face_to_definition(def_droite, pts_droite)	
				end
			end
			if(last_component_name=="AUVENT_GARAGE")
				return def_face, def_gauche, def_dessus ,def_droite
			else
				return def_face, def_gauche, def_dessus 
			end
		end

		def self.place_views_in_a4(face, left, top, frame)
			model = Sketchup.active_model
			ents  = model.entities
			# Récupérer le bounding box du cadre
			bb = frame.bounds
			# Zones du cadre
			# Face en haut
			face_pos = Geom::Point3d.new(bb.min.x + 20.mm, bb.max.y - 20.mm, 0)
			# Gauche en bas
			left_pos = Geom::Point3d.new(bb.min.x + 20.mm, bb.min.y + 20.mm, 0)
			# Dessus en bas à droite
			top_pos = Geom::Point3d.new(bb.max.x - 150.mm, bb.min.y + 20.mm, 0)
			# Déplacer les vues
			face.move!(Geom::Transformation.new(face_pos - face.bounds.min))
			left.move!(Geom::Transformation.new(left_pos - left.bounds.min))
			top.move!(Geom::Transformation.new(top_pos - top.bounds.min))
		end

		def self.generate_plan_a4_layout(gauche ,face, dessus, droite=nil)
			model = Sketchup.active_model
			ents  = model.entities
			#Style
			styles = Sketchup.active_model.styles
			current_style = styles.selected_style
			if current_style.nil?
				#SU2017 bug : aucun style actif
				current_style = styles.first
				styles.selected_style = current_style
			end
			styles = Sketchup.active_model.styles
			white_style = styles["Plan mairie"]
			styles.selected_style = white_style if white_style
			#IMPORTANT : forcer le rafraîchissement du style
			model.active_view.refresh
			#Nettoyage ancien plan
			ents.grep(Sketchup::Group).each do |g|
				next unless g.name.to_s.start_with?("PLAN_A4")
				g.erase!
			end
			#Calcul automatique de l’échelle ===
			# On calcule la taille max des vues
			bb_face   = face.bounds
			bb_gauche = gauche.bounds
			bb_dessus = dessus.bounds
			max_width  = [bb_face.width + bb_gauche.width, bb_dessus.width].max
			max_height = bb_face.height + bb_dessus.height
			# Place disponible dans l’A4 (hors cartouche)
			#chosen_scale=0.04 pour auvent Nord
			chosen_scale=0.02
			#Création du cadre A4 ===
			a4_width  = 297.mm/chosen_scale
			a4_height = 210.mm/chosen_scale
			margin    = 10.mm/chosen_scale
			plan = ents.add_group
			plan.name = "PLAN_A4"
			layer_projection = model.layers["Projection"]
			plan.layer = layer_projection
			# Rectangle A4
			plan.entities.add_face(
				Geom::Point3d.new(0, 0, 0),
				Geom::Point3d.new(a4_width, 0, 0),
				Geom::Point3d.new(a4_width, a4_height, 0),
				Geom::Point3d.new(0, a4_height, 0)
			) 
			# --- Cartouche  ---
			# voir la fonction def self.create_a4_frame_with_cartouche
			cart_height = 0  #25.mm/chosen_scale
			#cartouche = plan.entities.add_group
			#cartouche.name = "CARTOUCHE"
			# Rectangle du cartouche
			#cart_face = cartouche.entities.add_face(
			#  [0, 0, 0],
			#  [a4_width, 0, 0],
			#  [a4_width, cart_height, 0],
			#  [0, cart_height, 0]
			#)
			#cart_face.material = "white"
			# Bordure du cartouche
			#cart_face.erase!
			#cartouche.entities.add_line([0,0,0], [a4_width,0,0])
			#cartouche.entities.add_line([a4_width,0,0], [a4_width,cart_height,0])
			#cartouche.entities.add_line([a4_width,cart_height,0], [0,cart_height,0])
			#cartouche.entities.add_line([0,cart_height,0], [0,0,0])
			# --- Texte du cartouche ---
			#text_height = 4.mm/chosen_scale
			#margin = 3.mm/chosen_scale
			# --- Texte du cartouche ---
			#xtext = 3.mm/chosen_scale
			#x2text = a4_width/2 +xtext
			#ztext = 4.mm/chosen_scale
			#ytext1 = cart_height - 7.mm/chosen_scale
			#ytext2 = ytext1 - 7.mm/chosen_scale
			#ytext3 = ytext2 - 7.mm/chosen_scale
			generate_vector_alphabet
			# les instances dans le plan A4
			new_face   = plan.entities.add_instance(face, IDENTITY)
			new_gauche = plan.entities.add_instance(gauche, IDENTITY)
			new_dessus = plan.entities.add_instance(dessus, IDENTITY)
			if(last_component_name=="AUVENT_GARAGE")
				new_droite = plan.entities.add_instance(droite, IDENTITY)
			end
			tr_rot_face = Geom::Transformation.rotation(ORIGIN, Z_AXIS, 90.degrees)  #OK en XY
			new_face.transform!(tr_rot_face)
			tr_rot_face1 = Geom::Transformation.rotation(ORIGIN, X_AXIS,  90.degrees)  #OK en XY
			new_face.transform!(tr_rot_face1)
			tr_mirror = Geom::Transformation.scaling(ORIGIN, 1, -1, 1)
			new_face.transform!(tr_mirror)
			tr_mirror = Geom::Transformation.scaling(ORIGIN, -1, 1, 1)
			new_face.transform!(tr_mirror)	
			tr_rot_gauche_z = Geom::Transformation.rotation(ORIGIN, Z_AXIS, 90.degrees)
			new_gauche.transform!(tr_rot_gauche_z)
			tr_rot_gauche_xy = Geom::Transformation.rotation(ORIGIN, X_AXIS,  90.degrees)  #OK en XY
			new_gauche.transform!(tr_rot_gauche_xy)
			tr_mirror = Geom::Transformation.scaling(ORIGIN, 1, -1, 1)
			new_gauche.transform!(tr_mirror)
			if(last_component_name=="AUVENT_GARAGE")
				new_droite.transform!(tr_rot_gauche_z)
				new_droite.transform!(tr_rot_gauche_xy)
				new_droite.transform!(tr_mirror)
				tr_mirror_dr = Geom::Transformation.scaling(ORIGIN, -1, 1, 1)
				new_droite.transform!(tr_mirror_dr)	
			end
			# --- Layer Projection ---
			fb = new_face.bounds
			gb = new_gauche.bounds
			db = new_dessus.bounds
			fw = fb.max.x - fb.min.x
			fh = fb.max.y - fb.min.y
			gw = gb.max.x - gb.min.x
			gh = gb.max.y - gb.min.y
			dw = db.max.x - db.min.x
			dh = db.max.y - db.min.y
			espX = (a4_width - (fw + gw )) / 3
			x_face =espX-fb.min.x  
			x_dessus = x_face 
			x_gauche =espX + fw + espX - gb.min.x
			if(last_component_name=="AUVENT_GARAGE")
				x_droite = x_gauche
			end
			espY = (a4_height - cart_height - (fh + dh ).to_f) / 3
			y_dessus = cart_height + espY
			y_face   = y_dessus + dh + espY
			y_gauche = y_face
			if(last_component_name=="AUVENT_GARAGE")
				y_droite = y_face
			end
			#Symbole Terrain Naturel (TN) ---
			if(last_component_name=="ABRI_SUD")
				# Position de la ligne TN
				niveau_y = y_face
				x1 = espX
				x2 = a4_width-espX 
				# Ligne horizontale TN
				plan.entities.add_line([x1, niveau_y, 0], [x2, niveau_y, 0])
				x3 = fw + espX
				y1=niveau_y-30.mm/chosen_scale
				y2=niveau_y-15.mm/chosen_scale
				plan.entities.add_line([x1, y1, 0], [x3, y2, 0])
				# --- Hachures TN ---
				hachure_y1 = y1 - 1.mm/chosen_scale
				hachure_y2 = y1 - 4.mm/chosen_scale
				hachure_y21 = y2 - 1.mm/chosen_scale
				# Espacement des hachures
				espacement = 4.mm/chosen_scale
				x1_hachures=x1
				x2_hachures=x3
				x=x1_hachures
				nb_pas=(x2_hachures-x1_hachures)/espacement
				delta_y=(hachure_y21-hachure_y1)/nb_pas
				while x < x2_hachures
					plan.entities.add_line([x, hachure_y1, 0], [x + 2.mm/chosen_scale, hachure_y2, 0])
					x += espacement
					hachure_y1+=delta_y
					hachure_y2+=delta_y
				end
				# --- Texte vectoriel "TN" ---
				x1_tn=5.mm/chosen_scale
				x2_tn=fw + espX + 5.mm/chosen_scale
				draw_vector_text(
					plan,
					"TN: 47.80m", 
					x1_tn, 
					niveau_y - 30.mm / chosen_scale,
					4.mm / chosen_scale 
				)
				draw_vector_text(
					plan,
					"TN: 48.0m",
					x2_tn,
					niveau_y - 15.mm / chosen_scale,
					4.mm / chosen_scale
				)
			elsif(last_component_name=="AUVENT_NORD")
				# --- Symbole Terrain Naturel (TN) ---
				# Position de la ligne TN
				largeur_face=fw
				niveau_y = y_face 
				x1 = x_face
				x2 = x_face + largeur_face
				x1 = x_gauche -  2.mm/chosen_scale  #x1
				# Ligne horizontale TN
				plan.entities.add_line([x1, niveau_y, 0], [x2, niveau_y, 0])
				# --- Hachures TN ---
				hachure_y1 = niveau_y - 1.mm/chosen_scale
				hachure_y2 = niveau_y - 4.mm/chosen_scale
				# Espacement des hachures
				espacement = 4.mm/chosen_scale
				x=x1
				while x < x2
					plan.entities.add_line([x, hachure_y1, 0], [x + 2.mm/chosen_scale, hachure_y2, 0])
					x += espacement
				end
				# --- Texte vectoriel "TN" ---
				draw_vector_text(
					plan,
					"TN: 48.70m",
					x_gauche+10.mm/chosen_scale,
					niveau_y +1.mm/chosen_scale,
					4.mm/chosen_scale
				)
			
			elsif(last_component_name=="ABRI_VOITURE")	
				# --- Symbole Terrain Naturel (TN) ---
				# Position de la ligne TN
				largeur_face=fw
				niveau_y = y_face 
				x1 = espX 
				x2 = a4_width - espX 
				# Ligne horizontale TN
				plan.entities.add_line([x1, niveau_y, 0], [x2, niveau_y, 0])
				# --- Hachures TN ---
				hachure_y1 = niveau_y - 1.mm/chosen_scale
				hachure_y2 = niveau_y - 4.mm/chosen_scale
				# Espacement des hachures
				espacement = 4.mm/chosen_scale
				x=x1
				while x < x2
					plan.entities.add_line([x, hachure_y1, 0], [x + 2.mm/chosen_scale, hachure_y2, 0])
					x += espacement
				end
				# --- Texte vectoriel "TN" ---
				draw_vector_text(
					plan,
					"TN: 47.90m",
					largeur_face + espX,
					niveau_y + 1.mm/chosen_scale,
					4.mm/chosen_scale
				)
			elsif(last_component_name=="AUVENT_GARAGE")
				# Position de la ligne TN
				largeur_face=fw
				niveau_y_1 = y_face
				niveau_y_2 = niveau_y_1+(largeur_face/6341.mm) * 300.mm
				x1 = espX
				x2 = x1 + largeur_face
				# Ligne horizontale TN
				plan.entities.add_line([x1, niveau_y_1, 0], [x2, niveau_y_2, 0])
				# --- Symbole Terrain Naturel (TN) ---
				espacement = 4.mm/chosen_scale
				x1_hachures=x1
				x2_hachures=x2
				x=x1_hachures
				hachure_y1 = niveau_y_1 - 1.mm/chosen_scale
				hachure_y2 = niveau_y_1 - 4.mm/chosen_scale
				hachure_y21 = niveau_y_2 - 1.mm/chosen_scale
				nb_pas=(x2_hachures-x1_hachures)/espacement
				delta_y=(hachure_y21-niveau_y_1)/nb_pas
				while x < x2_hachures
					plan.entities.add_line([x, hachure_y1, 0], [x + 2.mm/chosen_scale, hachure_y2, 0])
					x += espacement
					hachure_y1+=delta_y
					hachure_y2+=delta_y
				end
				# --- Texte vectoriel "TN" ---
				draw_vector_text(
					plan,
					"TN: 47.80m",
					largeur_face + espX + 20.mm,
					niveau_y_1 + 1.mm/chosen_scale,
					4.mm/chosen_scale 
				)
				# --- Texte vectoriel "TN" ---
				draw_vector_text(
					plan,
					"TN: 47.50m",
					20.mm,
					niveau_y_2 - 15.mm/chosen_scale,
					4.mm/chosen_scale
				)
				draw_vector_text(
					plan,
					"Vue Sud",
					x_gauche + 10.mm/chosen_scale,
					y_gauche - 10.mm/chosen_scale,
					4.mm/chosen_scale
				)
				draw_vector_text(
					plan,
					"Vue Nord",
					x_gauche + 10.mm/chosen_scale,
					y_dessus - 10.mm/chosen_scale,
					4.mm/chosen_scale
				)		
				else
					UI.messagebox("paramètres TN: nom pas trouvé,renommez le ou modifier ce if ou ajoutez le éventuellement sans traitement")
			end
			new_face.transform!(Geom::Transformation.translation([x_face, y_face, 0]))
			new_dessus.transform!(Geom::Transformation.translation([x_face, y_dessus, 0]))
			new_gauche.transform!(Geom::Transformation.translation([x_gauche, y_gauche, 0]))
			if(last_component_name=="AUVENT_GARAGE")
				new_droite.transform!(Geom::Transformation.translation([largeur_face + 2*espX, y_dessus, 0]))
			end
			model = Sketchup.active_model
			view  = model.active_view
			# Forcer le contexte racine
			model.close_active
			#  S'assurer que la layer Projection est visible
			layer_proj = model.layers["Projection"]
			layer_proj.visible = true if layer_proj
			#Cacher la layer Auvent
			layer_auvent = model.layers["Auvent"]
			layer_auvent.visible = false if layer_auvent
			# Vue TOP
			Sketchup.send_action("viewTop:")
			# Refresh (important en SU2017)
			view.refresh
			# Zoom extents (2 fois pour SU2017)
			UI.start_timer(0.1, false) {
				model.active_view.zoom_extents
			}
			# Restaurer le style d’origine
			#styles.selected_style = current_style
			return plan
		end

		def self.draw_vector_text(group, text, x, y, height_mm)
			model = Sketchup.active_model
			defs  = model.definitions
			scale = height_mm / 4.mm
			cursor = Geom::Point3d.new(x, y, 0)
			text.each_char do |char|
			# --- Gestion de l'espace ---
			if char == " "
				cursor.x += 2.mm * scale   # largeur de l’espace
				next
			end
			comp_def = defs[char]
			next unless comp_def
				tr = Geom::Transformation.new(cursor)
				tr = tr * Geom::Transformation.scaling(scale)
				group.entities.add_instance(comp_def, tr)
				cursor.x += 3.mm * scale   # largeur d’une lettre
			end
		end

		def self.generate_vector_alphabet
			model = Sketchup.active_model
			defs  = model.definitions
			alphabet = {
			"A" => [[0,0,0,4],[0,4,2,4],[2,4,2,0],[0,2,2,2]],
			"B" => [[0,0,0,4],[0,4,2,3],[2,3,0,2],[0,2,2,1],[2,1,0,0]],
			"C" => [[2,0,0,0],[0,0,0,4],[0,4,2,4]],
			"D" => [[0,0,0,4],[0,4,2,3],[2,3,2,1],[2,1,0,0]],
			"E" => [[2,0,0,0],[0,0,0,4],[0,4,2,4],[0,2,1.5,2]],
			"F" => [[0,0,0,4],[0,4,2,4],[0,2,1.5,2]],
			"G" => [[2,0,0,0],[0,0,0,4],[0,4,2,4],[2,4,2,2],[2,2,1,2]],
			"H" => [[0,0,0,4],[2,0,2,4],[0,2,2,2]],
			"I" => [[1,0,1,4]],
			"J" => [[2,4,2,0],[2,0,0,0],[0,0,0,1]],
			"K" => [[0,0,0,4],[0,2,2,4],[0,2,2,0]],
			"L" => [[0,4,0,0],[0,0,2,0]],
			"M" => [[0,0,0,4],[0,4,1,2],[1,2,2,4],[2,4,2,0]],
			"N" => [[0,0,0,4],[0,4,2,0],[2,0,2,4]],
			"O" => [[0,0,0,4],[0,4,2,4],[2,4,2,0],[2,0,0,0]],
			"P" => [[0,0,0,4],[0,4,2,4],[2,4,2,2],[2,2,0,2]],
			"Q" => [[0,0,0,4],[0,4,2,4],[2,4,2,0],[2,0,0,0],[1,1,2,0]],
			"R" => [[0,0,0,4],[0,4,2,4],[2,4,2,2],[2,2,0,2],[0,2,2,0]],
			"S" => [[2,4,0,4],[0,4,0,2],[0,2,2,2],[2,2,2,0],[2,0,0,0]],
			"T" => [[0,4,2,4],[1,4,1,0]],
			"U" => [[0,4,0,0],[0,0,2,0],[2,0,2,4]],
			"V" => [[0,4,1,0],[1,0,2,4]],
			"W" => [[0,4,0,0],[0,0,1,2],[1,2,2,0],[2,0,2,4]],
			"X" => [[0,0,2,4],[0,4,2,0]],
			"Y" => [[0,4,1,2],[2,4,1,2],[1,2,1,0]],
			"Z" => [[0,4,2,4],[2,4,0,0],[0,0,2,0]],
			"0" => [[0,0,0,4],[0,4,2,4],[2,4,2,0],[2,0,0,0]],
			"1" => [[1,0,1,4]],
			"2" => [[0,4,2,4],[2,4,2,2],[2,2,0,0],[0,0,2,0]],
			"3" => [[0,4,2,4],[2,4,2,0],[2,0,0,0],[2,2,0,2]],
			"4" => [[0,4,0,2],[0,2,2,2],[2,4,2,0]],
			"5" => [[2,4,0,4],[0,4,0,2],[0,2,2,2],[2,2,2,0],[2,0,0,0]],
			"6" => [[2,4,0,4],[0,4,0,0],[0,0,2,0],[2,0,2,2],[2,2,0,2]],
			"7" => [[0,4,2,4],[2,4,0,0]],
			"8" => [[0,0,0,4],[0,4,2,4],[2,4,2,0],[2,0,0,0],[0,2,2,2]],
			"9" => [[2,0,2,4],[2,4,0,4],[0,4,0,2],[0,2,2,2]],
			":" => [[1,3,1,3],[1,1,1,1]],
			"-" => [[0,2,2,2]],
			"/" => [[0,0,2,4]],
			"." => [
			[0.6,0, 1.4,0],
			[1.4,0, 1.4,0.8],
			[1.4,0.8, 0.6,0.8],
			[0.6,0.8, 0.6,0]
			]
			}
			alphabet.each do |char, segs|
				comp = defs.add(char)
				ents = comp.entities
				segs.each do |x1,y1,x2,y2|
					ents.add_line([x1.mm, y1.mm, 0], [x2.mm, y2.mm, 0])
				end
			end
		end

		def self.generate_2d_views
		
			model = Sketchup.active_model
			sel   = model.selection
			layer_projection = model.layers["Projection"]
			grp = sel.grep(Sketchup::Group).first
			unless grp
				UI.messagebox("Sélectionnez le groupe de l'auvent.")
				return
			end
			# Nettoyage des anciennes vues
			model.entities.grep(Sketchup::Group).each do |g|
				g.erase! if g.name.start_with?("Vue 2D")
			end
			# Récupération de toutes les arêtes transformées
			edges = UtilsAuvent.collect_edges_with_transform(grp)
			if edges.empty?
				UI.messagebox("Aucune géométrie trouvée dans l'auvent.")
				return
			end
			# --- Vue de face (projection YZ) ---
			grp_face = model.entities.add_group
			grp_face.layer = layer_projection
			grp_face.name  = "Vue 2D — Face"
			edges.each do |p1, p2|
				grp_face.entities.add_line(
				Geom::Point3d.new(0, p1.y, p1.z),
				Geom::Point3d.new(0, p2.y, p2.z)
				)
			end
			# --- Vue de gauche (projection XZ) ---
			grp_left = model.entities.add_group
			grp_left.layer = layer_projection
			grp_left.name  = "Vue 2D — Gauche"
			edges.each do |p1, p2|
				grp_left.entities.add_line(
				Geom::Point3d.new(p1.x, 0, p1.z),
				Geom::Point3d.new(p2.x, 0, p2.z)
				)
			end
			UI.messagebox("Vues 2D générées.")
		end

		#pas utilisé à revoir
		def self.create_a4_frame_with_cartouche
			model = Sketchup.active_model
			ents  = model.entities
			# Dimensions A4 paysage en mm
			width  = 297.mm
			height = 210.mm
			# Groupe cadre
			grp = ents.add_group
			grp.name = "A4_FRAME"
			# Cadre extérieur
			p1 = Geom::Point3d.new(0, 0, 0)
			p2 = Geom::Point3d.new(width, 0, 0)
			p3 = Geom::Point3d.new(width, height, 0)
			p4 = Geom::Point3d.new(0, height, 0)
			grp.entities.add_line(p1, p2)
			grp.entities.add_line(p2, p3)
			grp.entities.add_line(p3, p4)
			grp.entities.add_line(p4, p1)
			# Cartouche stylé (hauteur 25 mm)
			cartouche_h = 25.mm
			y_cart = cartouche_h
			# Ligne horizontale séparatrice
			grp.entities.add_line(
				Geom::Point3d.new(0, cartouche_h, 0),
				Geom::Point3d.new(width, cartouche_h, 0)
			)
			# Colonnes du cartouche
			col1 = 80.mm
			col2 = 160.mm
			grp.entities.add_line(Geom::Point3d.new(col1, 0, 0), Geom::Point3d.new(col1, cartouche_h, 0))
			grp.entities.add_line(Geom::Point3d.new(col2, 0, 0), Geom::Point3d.new(col2, cartouche_h, 0))
			# Texte du cartouche
			grp.entities.add_text("projet", Geom::Point3d.new(5.mm, 5.mm, 0))
			grp.entities.add_text("Adresse : [à compléter]", Geom::Point3d.new(col1 + 5.mm, 5.mm, 0))
			grp.entities.add_text("Commune : xxx (xxx)", Geom::Point3d.new(col2 + 5.mm, 5.mm, 0))
			grp.entities.add_text("Date : #{Time.now.strftime("%d/%m/%Y")}", Geom::Point3d.new(5.mm, cartouche_h - 10.mm, 0))
			grp.entities.add_text("Auteur : xxx", Geom::Point3d.new(col1 + 5.mm, cartouche_h - 10.mm, 0))
			grp.entities.add_text("Logiciel : SketchUp 2017 + projet", Geom::Point3d.new(col2 + 5.mm, cartouche_h - 10.mm, 0))
			grp
		end

		#*********************************Panneaux**************************************

		def self.add_panneau_clins_3d(name,parent, origin,
			largeur_totale, hauteur, pas, ep,
			material_name,id: :id_sym, chanfrein: 2.mm, delta_hauteur: 0.mm,
			orientation: :vertical,normal: :xplus)
			ents  = parent.entities
			clins_group = ents.add_group
			clins_group.name = "PANNEAU CLINS"
			clins_group.layer = parent.layer
			# On pose l'attribut sur le groupe
			clins_group.set_attribute("panneau", "id", id.to_s)
			gents = clins_group.entities
			# -----------------------------
			# Repère local → global (base)
			# -----------------------------
			case normal
			when :xplus, :xminus		#on considère les 2 faces profilées identiques
				xaxis = Geom::Vector3d.new(1, 0, 0)
				yaxis = Geom::Vector3d.new(0, 1, 0)
			when :yplus,:yminus
				xaxis = Geom::Vector3d.new(0, -1, 0)
				yaxis = Geom::Vector3d.new(-1, 0, 0)
			end
			zaxis = Geom::Vector3d.new(0, 0, 1)
			# Transformation de base
			tr_global = Geom::Transformation.axes(origin, xaxis, yaxis, zaxis)
			# -----------------------------
			# Rotations supplémentaires pour HORIZONTAL
			# -----------------------------
			c = chanfrein
			faces = []
			# -----------------------------
			# Nombre de lames
			# -----------------------------
			nb_lames = (hauteur.to_f / pas).ceil
			pas=hauteur.to_f/nb_lames
			# -----------------------------
			# Création des sections (local) + transformation globale
			# -----------------------------
			nb_lames.times do |i|
				z0 = i * pas
				h  = pas
				l=14.mm  #languette visible hors chanfrein
				pts_local = [
					Geom::Point3d.new(0,     0, z0 + c),
					Geom::Point3d.new(0,     0, z0 + h -l - c),
					Geom::Point3d.new(c,     0, z0 + h - l),
					Geom::Point3d.new(c,     0, z0 + h),
					Geom::Point3d.new(ep-c,  0, z0 + h),
					Geom::Point3d.new(ep-c,  0, z0 + h - l),
					Geom::Point3d.new(ep ,   0, z0 + h -l - c),
					Geom::Point3d.new(ep,    0, z0 + c),
					Geom::Point3d.new(ep - c,0, z0),
					Geom::Point3d.new(c,     0, z0)		
				]
				# Transformation locale → monde
				pts_world = pts_local.map { |p| p.transform(tr_global) }
				lame_group = gents.add_group
				lame_group.name="LAME"
				lame_group.layer = parent.layer
				lame_face  = lame_group.entities.add_face(pts_world)
				faces << lame_face if lame_face
			end
			# -----------------------------
			# Extrusion material
			# -----------------------------
			mat = @materials[material_name]			
			faces.each do |f|
				f.material = mat
				f.back_material = mat
				f.pushpull(largeur_totale)	
			end
			if(last_component_name!="ABRI_SUD")	
				ossature_group = get_ossature_group()
				chevrons=get_chevrons_group(ossature_group)	
				coupe_panneau_auto(clins_group,chevrons,mat,1)	
			end
			clins_group
		end

		def self.add_panneau_lambris_3d(name,parent, origin,
					largeur_totale, hauteur, pas, ep,
					espace,material_name,id: :id_sym, chanfrein: 2.mm, delta_hauteur: 0.mm,
					orientation: :vertical, normal: :xplus)
			ents  = parent.entities
			lambris_group = ents.add_group
			lambris_group.name="PANNEAU LAMBRIS"
			lambris_group.layer = parent.layer
			# On pose l'attribut sur le groupe
			lambris_group.set_attribute("panneau", "id", id.to_s)
			gents = lambris_group.entities
			# -----------------------------
			# Repère local → global (base)
			# -----------------------------
			case normal
			when :xplus, :xminus		#on considère les 2 faces profilées identiques
				xaxis = Geom::Vector3d.new(1, 0, 0)
				yaxis = Geom::Vector3d.new(0, 1, 0)
			when :yplus,:yminus
				xaxis = Geom::Vector3d.new(0, -1, 0)
				yaxis = Geom::Vector3d.new(-1, 0, 0)
			end
			zaxis = Geom::Vector3d.new(0, 0, 1)
			# Transformation de base
			tr_global = Geom::Transformation.axes(origin, xaxis, yaxis, zaxis)
			# -----------------------------
			# Rotations supplémentaires pour VERTICAL
			# -----------------------------
			if orientation == :vertical
				case normal
					when :xplus, :xminus
						tr_rotZ = Geom::Transformation.rotation(origin, Z_AXIS, 90.degrees)
						tr_rotX = Geom::Transformation.rotation(origin, Y_AXIS, -90.degrees)
						tr_global = tr_rotX * tr_rotZ * tr_global
					when :yplus, :yminus
						tr_rotZ = Geom::Transformation.rotation(origin, Z_AXIS, 90.degrees)
						tr_rotX = Geom::Transformation.rotation(origin, X_AXIS, -90.degrees)
						tr_global = tr_rotX * tr_rotZ * tr_global
				end
			end
			c = chanfrein
			faces = []
			# -----------------------------
			# Nombre de lames
			# -----------------------------
			if orientation == :vertical
				nb_lames = (largeur_totale.to_f / pas).ceil
				pas=largeur_totale.to_f/nb_lames
			else
				nb_lames = (hauteur.to_f / pas).ceil
				pas=hauteur.to_f/nb_lames
			end
			# -----------------------------
			# Création des sections (local) + transformation globale
			# -----------------------------
			pts_world = Array.new(nb_lames) { [] }
			nb_lames.times do |i|
				if orientation == :vertical
					x0 = i * pas
					w  = pas
					pts_local = [
						Geom::Point3d.new(x0 + c,     0, 0),
						Geom::Point3d.new(x0 + w-espace - c, 0, 0),
						Geom::Point3d.new(x0 + w-espace,     0, c ),
						Geom::Point3d.new(x0 + w-espace,     0, ep - c),
						Geom::Point3d.new(x0 + w-espace - c, 0, ep),
						Geom::Point3d.new(x0 + c,     0, ep),
						Geom::Point3d.new(x0,         0, ep - c),
						Geom::Point3d.new(x0,         0, c)
					]
				else
					z0 = i * pas
					h  = pas
					pts_local = [
						Geom::Point3d.new(0,     0, z0 + c),
						Geom::Point3d.new(0,     0, z0 + h - c),
						Geom::Point3d.new(c,     0, z0 + h),
						Geom::Point3d.new(ep - c,0, z0 + h),
						Geom::Point3d.new(ep,    0, z0 + h - c),
						Geom::Point3d.new(ep,    0, z0 + c),
						Geom::Point3d.new(ep - c,0, z0),
						Geom::Point3d.new(c,     0, z0)
					]
				end
				# Transformation locale → monde
				pts_world[i] = pts_local.map { |p| p.transform(tr_global) }
				lame_group = gents.add_group
				lame_group.name="LAME"
				lame_group.layer = parent.layer
				lame_face  = lame_group.entities.add_face(pts_world[i])
				faces << lame_face if lame_face
			end
			model = Sketchup.active_model
			mat = @materials[material_name]
			# -----------------------------
			# Extrusion
			# -----------------------------
			if orientation == :horizontal
				faces.each do |f|
					f.material = mat
					f.back_material = mat
						f.pushpull(largeur_totale)
				end
			else # vertical
				case normal 
				when :xplus, :xminus
					delta=delta_hauteur/nb_lames
					faces.each_with_index do |f, i|
						x0 = i * pas
						ratio = x0 / largeur_totale.to_f
						hauteur_lame = hauteur + ratio * delta_hauteur
						##       f.material = mat
						##       f.back_material = mat
					f.pushpull(hauteur_lame)
				end
				ossature_group = get_ossature_group()
				chevrons=get_chevrons_group(ossature_group)	
				coupe_panneau_auto( lambris_group,chevrons,mat)	
			else
				faces.each do |f|
					f.material = mat
					f.back_material = mat
					f.pushpull(hauteur)
				end
			end
		  end
		  return lambris_group,pts_world
		end
		
		def self.add_panneau_cutter(parent,pts,id: :id_sym,normal: :xplus) 
			gents  = parent.entities
			id_str = id.to_s
			clins_group = trouver_panneau_par_id_recursif(id_str,gents)  #marchait 
			lames = clins_group.entities.grep(Sketchup::Group)
			lames.each do |lame|
				coupe_lambris_sur_points(lame,pts,normal: normal)
				model = Sketchup.active_model
				model.commit_operation
			end
		end

		def self.extrude_panneau_polycarbonate(root, pts, profil, pas, material_name,nom_group)
			#  Créer un groupe pour la couverture
			gents=root.entities
			g = root.entities.add_group
			g.name = nom_group
			g.layer = root.layer
			# Récupérer les entities du groupe
			cov_ents = g.entities
			# --- Points du toit ---
			p1, p2, p3, p4 = pts
			x_axis = p1.vector_to(p2)
			x_axis.normalize!
			# --- Axe Z : normale du toit (p1,p2,p4) ---
			z_axis = p1.vector_to(p2) * p1.vector_to(p4)
			z_axis.normalize!
			# --- Axe Y : perpendiculaire à X et Z ---
			y_axis = z_axis * x_axis
			y_axis.normalize!
			# --- Transformation du profil dans le repère du toit ---
			profil_global = profil.map do |pt|
				# IMPORTANT : conversion en Float ici aussi (SU2017 renvoie toujours Length)
				x = pt.x.to_f          #undefined method `to_f' for Point3d(0.00393701, 0, 0):Geom::Point3d>
				y = pt.y.to_f
				z = pt.z.to_f
				vx = x_axis.x * x + y_axis.x * y + z_axis.x * z    #Geom::Point3d can't be coerced into Float>
				vy = x_axis.y * x + y_axis.y * y + z_axis.y * z
				vz = x_axis.z * x + y_axis.z * y + z_axis.z * z
				Geom::Point3d.new(
					p1.x + vx,
					p1.y + vy,
					p1.z + vz
				)
			end  #profil.map do |pt|
			pas_f = pas.to_f
			largeur_panneau = p1.distance(p2)
			longueur_panneau = p1.distance(p4)
			nb_panneaux = 1    #(largeur_panneau / (pas+delta_x_entre_tuiles)).ceil 
			largeur_totale_f = largeur_panneau.to_f
			largeur_restante = largeur_totale_f - (pas_f.to_f * (nb_panneaux - 1))
			edge_gauche = gents.add_line(p1, p4)
			nb_panneaux.times do |i|
				offset_x = x_axis.clone
				pts = profil_global.map { |p| p + offset_x }	
				precision = 3 # nombre de décimales	
				face = cov_ents.add_face(pts)
				next unless face
				face.reverse! if face.normal.dot(z_axis) < 0
				normal = face.normal  
				if normal.angle_between(Y_AXIS) > 90.degrees
					face.reverse!
				end
				face.pushpull(longueur_panneau)
			end   # end of nb_panneaux.times do |i|
			edge_gauche.erase! if edge_gauche.valid?
			cov_ents.grep(Sketchup::Edge).each { |e| 
				e.soft = true
				e.smooth = true
			}
			mat = @materials[material_name]
			UtilsAuvent.apply_material_stable(cov_ents, mat)
		end

		def self.extrude_couverture_ondulée(root, pts, profil_local, pas, material_name,longueur_tuiles=0,delta_x_entre_tuiles=0.mm,corrige_x0=0)
			delta_y_entre_tuiles=2.mm      #pour voir le joint
			# 1) Créer un groupe pour la couverture
			gents=root.entities
			g = root.entities.add_group
			g.name = "COUVERTURE"
			g.layer = root.layer
			# 2) Récupérer les entities du groupe
			cov_ents = g.entities
			# --- Points du toit ---
			p1, p2, p3, p4 = pts
			# --- Axe X : direction p1->p2 ---
			x_axis = p1.vector_to(p2)
			x_axis.normalize!
			# --- Axe Z : normale du toit (p1,p2,p4) ---
			z_axis = p1.vector_to(p2) * p1.vector_to(p4)
			z_axis.normalize!
			# --- Axe Y : perpendiculaire à X et Z ---
			y_axis = z_axis * x_axis
			y_axis.normalize!
			# --- Transformation du profil dans le repère du toit ---
			profil_global = profil_local.map do |pt|
				# IMPORTANT : conversion en Float ici aussi (SU2017 renvoie toujours Length)
				x = pt.x.to_f 
				y = pt.y.to_f
				z = pt.z.to_f
				vx = x_axis.x * x + y_axis.x * y + z_axis.x * z    #Geom::Point3d can't be coerced into Float>
				vy = x_axis.y * x + y_axis.y * y + z_axis.y * z
				vz = x_axis.z * x + y_axis.z * y + z_axis.z * z
				Geom::Point3d.new(
					p1.x + vx,
					p1.y + vy,
					p1.z + vz
				)
			end  #  profil.map do |pt|
		#*********************longueur du toit******************************
			longueur_toit = p1.distance(p2)
			pas_reel=pas 
			nb_panneaux = (longueur_toit / pas_reel).ceil 
			pas_reel=longueur_toit/nb_panneaux
			longueur_totale = longueur_toit     # a voir si debord
			
		#*********************largeur du toit**********************************	
			largeur_toit = p1.distance(p4)
			if longueur_tuiles >0
				nb_tuile=(largeur_toit/(longueur_tuiles+delta_y_entre_tuiles)).ceil
				longueur_tuiles_visible=largeur_toit/nb_tuile
			end
			edge_gauche = gents.add_line(p1, p4)
			offset_x_length=corrige_x0 
			nb_panneaux.times do |i|
				offset_x = x_axis.clone
				offset_x.length = offset_x_length
				pas_local = pas_reel 
				offset_x_length += pas_local
				pts = profil_global.map { |p| p + offset_x }
				
				face = cov_ents.add_face(pts)
				
				precision = 3 # nombre de décimales	
				if longueur_tuiles > 0
					nb_tuile.times do |j|
						offset_y = y_axis.clone 
						offset_y.length = (j == 0) ? 0 : longueur_tuiles_visible  
						pts = pts.map { |p| p.transform(offset_y) }
						offset_z = z_axis.clone
						offset_z.length=j*1.mm
						pts = pts.map { |p| p.transform(offset_z) }
						face = cov_ents.add_face(pts)
						face.reverse! if face.normal.dot(z_axis) < 0
						# Forcer extrusion vers +Y si nécessaire
						normal = face.normal  
						if normal.angle_between(Y_AXIS) > 90.degrees
							face.reverse!
						end
						face.pushpull(longueur_tuiles_visible-delta_y_entre_tuiles)
					end 
				else			#c'est un panneau
					face = cov_ents.add_face(pts)
					next unless face
					face.reverse! if face.normal.dot(z_axis) < 0
					normal = face.normal  
					if normal.angle_between(Y_AXIS) > 90.degrees
						face.reverse!
					end
					face.pushpull(largeur_toit)
				end
			end   #nb_panneaux.times do |i|
		edge_gauche.erase! if edge_gauche.valid?
		cov_ents.grep(Sketchup::Edge).each { |e| 
		  e.soft = true
		  e.smooth = true
		}
		mat = @materials[material_name]
		UtilsAuvent.apply_material_stable(cov_ents, mat)
		end
		
		def self.coupe_panneau_auto(lambris_group, chevrons,mat,cas=0)
			lames = lambris_group.entities.grep(Sketchup::Group)
			lames.each do |lame|
				ch = chevron_pour_lame(lame, chevrons)
				next unless ch
				coupe_lambris_sur_chevron(lame, ch,cas)
				model = Sketchup.active_model
				model.commit_operation
				reappliquer_materiau(lame,mat)
			end
		end

		def self.trouver_panneau_par_id_recursif(id, ents)
			id_str = id.to_s
			ents.each do |e|
				next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
				return e if e.get_attribute("panneau", "id").to_s == id_str
				sub = e.entities rescue nil
				next unless sub
				found = trouver_panneau_par_id_recursif(id, sub)
				return found if found
			end
			nil
		end

		def self.extrude_piece(edge, sx, sy, material_name=nil)
			ents = edge.parent.entities
			start_pt = edge.start.position
			end_pt   = edge.end.position
			dir = end_pt - start_pt
			# Détection verticale (poteau)
			vertical = dir.parallel?(Geom::Vector3d.new(0,0,1))
			# Construction du profil dans un repère local
			if vertical
				# Profil pour un poteau vertical
				xaxis = Geom::Vector3d.new(1,0,0)
				yaxis = Geom::Vector3d.new(0,1,0)
				zaxis = Geom::Vector3d.new(0,0,1)
				origin = start_pt
			else
				# Profil pour une poutre horizontale
				zaxis = dir.clone
				zaxis.length = 1
				xaxis = zaxis.cross(Geom::Vector3d.new(0,0,1))
				xaxis = Geom::Vector3d.new(1,0,0) if xaxis.length == 0
				xaxis.length = 1
				yaxis = zaxis.cross(xaxis)
				yaxis.length = 1
				origin = start_pt
			end
			tr = Geom::Transformation.axes(origin, xaxis, yaxis, zaxis)
			pts = [
				Geom::Point3d.new(-sx/2, -sy/2, 0),
				Geom::Point3d.new( sx/2, -sy/2, 0),
					Geom::Point3d.new( sx/2,  sy/2, 0),
				Geom::Point3d.new(-sx/2,  sy/2, 0)
			].map { |p| p.transform(tr) }
			face = ents.add_face(pts)
			return unless face
			if vertical
				# -------------------------
				# POTEAU → FollowMe
				# -------------------------
				face.followme(edge)
			else
				# -------------------------
				# POUTRE → PushPull
				# -------------------------
				face.pushpull(dir.length)
			end
			edge.erase! if edge.valid?	
			apply_material(ents,material_name,dir)
		end

		#*********************************Pièces**************************************

		def self.piece_verticale(root, p)
			sx = p[1]
			sy = p[2]
			h  = p[3]
			x  = p[4]
			y  = p[5]
			z  = p[6]  
			mat = p[-1]
			group = root.entities.add_group
			group.name=p[0]
			group.layer = root.layer
			gents = group.entities
			edge = gents.add_line(
				Geom::Point3d.new(x, y, z),
				Geom::Point3d.new(x, y, h)
			)
			extrude_piece(edge, sx, sy, mat)
		end

		def self.piece_xy(root, p)
			sx = p[1]
			sy = p[2]
			x1 = p[3]
			y1 = p[4]
			z1 = p[5]
			x2 = p[6]
			y2 = p[7]
			z2 = p[8]
			mat = p[-1]
			g = root.entities.add_group
			if(last_component_name=="AUVENT_GARAGE")
				g.name="CHEVRON"                            #les chevrons sont dans la longueur
			else
				g.name=p[0]
			end
			g.layer = root.layer
			edge = g.entities.add_line(
				Geom::Point3d.new(x1, y1, z1),
				Geom::Point3d.new(x2, y2, z2)
			)
			extrude_piece(edge, sx, sy, mat)
			return g
		end
		
		def self.piece_renfort_45(root, p)
			sx = p[1]
			sy = p[2]
			x1 = p[3]
			y1 = p[4]
			z1 = p[5]
			x2 = p[6]
			y2 = p[7]
			z2 = p[8]
			mat = p[-1]
			g = root.entities.add_group
			g.name=p[0]
			g.layer = root.layer
			#genère Profil en xz
			profil_renfort_45(root,p)
			return g
		end

		def self.piece_pente(root, p)
			sx = p[1]
			sy = p[2]
			x  = p[3]
			y  = p[4]
			z  = p[5]
			len = p[6]
			angle_deg = p[7]
			mat = p[-1]
			angle_deg = p[7].to_s.gsub(/[^\d\.\-]/, '').to_f
			angle = angle_deg * Math::PI / 180.0
			dx = len * Math.cos(angle)
			dz = len * Math.sin(angle)
			g = root.entities.add_group
			g.name=p[0]
			g.layer = root.layer
			edge = g.entities.add_line(
				Geom::Point3d.new(x, y, z),
				Geom::Point3d.new(x + dx, y, z + dz)
			)
			extrude_piece(edge, sx, sy, mat)
		end

		def self.piece_direction(root, p)
			sx = p[1]
			sy = p[2]
			x1 = p[3]
			y1 = p[4]
			z1 = p[5]
			x2 = p[6]
			y2 = p[7]
			z2 = p[8]
			mat = p[-1]
			g = root.entities.add_group
			g.name = "POUTRE"
			g.layer = root.layer
			edge = g.entities.add_line(
				Geom::Point3d.new(x1, y1, z1),
				Geom::Point3d.new(x2, y2, z2)
			)
			extrude_piece(edge, sx, sy, mat)
		end

		def self.piece_panneau_clins(root, p)
			valid_normals = [:xplus, :xminus, :yplus, :yminus]
			#valid_orients = [:vertical, :horizontal]
			normal_sym      = p[6]
			orientation_sym = p[7]
			id_sym=p[11]
			# Position du panneau
			origin = Geom::Point3d.new(
				p[1].to_f,
				p[2].to_f,
				p[3].to_f
			)
			add_panneau_clins_3d(       #add_panneau_3d( 
				"PANNEAU CLINS",
				root,
				origin,
				p[4],     # largeur_totale
				p[5],     # hauteur
				p[8],     # pas
				p[9],     # ep
				p[-1],    # material_name
				id: id_sym,    #Id nécessaire si cutter  
				chanfrein: 5.0.mm,
				delta_hauteur: p[10],
				orientation: orientation_sym,
				normal: normal_sym
			)
		end

		def self.piece_panneau(root, p)
			new_pts = []
			new_pts[0] = Geom::Point3d.new(
				p[1].to_f,
				p[2].to_f,
				p[3].to_f
			)
			new_pts[2] = Geom::Point3d.new(
				p[4].to_f,
				p[5].to_f,
				p[6].to_f
			)
			# Position du panneau
			if (p[1]==p[4])   #x identiques
				new_pts[1] = Geom::Point3d.new(
					p[1].to_f,
					p[2].to_f,
					p[6].to_f
				)
				new_pts[3] = Geom::Point3d.new(
					p[1].to_f,
					p[5].to_f,
					p[3].to_f 
				)
			elsif (p[2]==p[5])  #y identiques
				new_pts[1] = Geom::Point3d.new(
					p[1].to_f,
					p[5].to_f,
					p[6].to_f
				)
				new_pts[3] = Geom::Point3d.new(
					p[4].to_f,
					p[5].to_f,
					p[3].to_f 
				)
			else
				puts ("panneaux traités vertical ou horizontal à compléter si nécessaire")
			end
			material_name=p[-1]
			thickness_i=p[7]
			v = new_pts[1] - new_pts[0]
			largeur = v.length
			model = Sketchup.active_model
			profil  = profil_polycarbonate_15mm_epais(thickness_i,largeur)  #  
			extrude_panneau_polycarbonate(root, new_pts, profil, largeur, material_name,p[0])	
		end

		def self.piece_panneau_lambris(root, p)
			largeur=p[4]
			normal_sym      = p[6]
			orientation_sym = p[7]
			id_sym= p[11]
			material_name=p[-1]
			# Position du panneau
			origin = Geom::Point3d.new(
				p[1].to_f,
				p[2].to_f,
				p[3].to_f
			)
			espace=0.001.mm
			lambris_group,pts_profil_lambris_world = add_panneau_lambris_3d(
				"PANNEAU LAMBRIS",
				root,
				origin,
				largeur,     # largeur_totale
				p[5],     # hauteur
				p[8],     # pas
				p[9],     # ep
				espace,
				material_name,    # material_name
				id: id_sym,    #Id 
				chanfrein: 3.0.mm,
				delta_hauteur: p[10],
				orientation: orientation_sym,
				normal: normal_sym
			)
			epaisseur_lames=p[9]
			if(last_component_name=="AUVENT_GARAGE" && id_sym == :porte && lambris_group != nil)  #
				entrouve_porte = Geom::Transformation.rotation(origin, Z_AXIS,  30.degrees) 
				lambris_group.transform!(entrouve_porte)
			end
			if(last_component_name=="AUVENT_GARAGE" && id_sym == :chapeau && lambris_group != nil)  #
				lames = lambris_group.entities.grep(Sketchup::Group)  
				nb_lame=lames.length
				hauteur_chapeau=133.mm
				nb_lamelle_par_lame=4
				p1 = Geom::Point3d.new(origin.x, origin.y , origin.z+p[5]-hauteur_chapeau)   #z=hauteur du bas du chapeau
				resolution = nb_lame * nb_lamelle_par_lame    #*4
				coupe_chapeau_double(lambris_group, largeur, hauteur_chapeau,p1,nb_lame,nb_lamelle_par_lame,pts_profil_lambris_world,epaisseur_lames,espace,resolution,material_name,normal: normal_sym)
			end
		end

		def self.piece_panneau_cutter(root, p)
			normal_sym      = p[13]
			id_sym=p[14]
			# Position du cutter
			pts = []
			pts[0] = Geom::Point3d.new(
				p[1].to_f,
			p[2].to_f,
				p[3].to_f
			)
			pts[1] = Geom::Point3d.new(
				p[4].to_f,
				p[5].to_f,
				p[6].to_f
			)
			pts[2] = Geom::Point3d.new(
				p[7].to_f,
				p[8].to_f,
				p[9].to_f
			)
			pts[3] = Geom::Point3d.new(
				p[10].to_f,
				p[11].to_f,
				p[12].to_f
			)
			add_panneau_cutter(
				root,
				pts,
				id: id_sym,    #Id panneau à couper  
				normal: normal_sym
			)
		end

		def self.piece_angle_yz(root, p)
			sx = p[1]
			sy = p[2]
			x  = p[3]
			y  = p[4]
			z  = p[5]
			len = p[6]
			# Nettoyage + conversion angle toiture → angle math
			angle_toiture = p[7].to_s.gsub(',', '.').to_f
			angle = (angle_toiture) * Math::PI / 180.0
			point_haut=p[8]
			dy = len * Math.cos(angle)
			dz = len * Math.sin(angle)
			dx = 0
			if(point_haut==0)
				new_y=y + dy
				new_z=z + dz
			else
				new_y=y - dy
				new_z=z - dz
			end
			g = root.entities.add_group
			g.name=p[0]
			g.layer = root.layer
			edge = g.entities.add_line(
				Geom::Point3d.new(x, y, z),
				Geom::Point3d.new(x + dx, new_y, new_z)
			)
			mat = p[-1]
			extrude_piece(edge, sx, sy, mat)
		end

		def self.piece_chevron(root, p)
			sx = p[1]
			sy = p[2]
			x  = p[3]
			y  = p[4]
			z  = p[5]
			len = p[6]
			hauteur_poutre = p[8]
			x2 = p[9]
			y2 = p[10]
			# --- Dépassement horizontal : 60 mm → converti en pouces ---
			dep_horiz = 60.mm
			# --- Angle toiture ---
			angle_toiture = p[7]
			angle = angle_toiture.degrees
			# --- Direction horizontale réelle ---
			dx_h = x2 - x
			dy_h = y2 - y
			dir_h = Geom::Vector3d.new(dx_h, dy_h, 0)
			dir_h.length = 1
			# --- Point de départ du chevron ---
			x0 = x + dir_h.x * dep_horiz
			y0 = y    #+ dir_h.y * dep_horiz
			z0 = z + hauteur_poutre
			# --- Direction du chevron ---
			dx = dir_h.x * len * Math.cos(angle)
			dy = dir_h.y * len * Math.cos(angle)
			dz = len * Math.sin(angle)
			# --- Création du groupe ---
			g = root.entities.add_group
			g.name = p[0]
			g.layer = root.layer
			# --- Ligne du chevron ---
			p1 = Geom::Point3d.new(x0, y0, z0)
			p2 = Geom::Point3d.new(x0 + dx, y0 + dy, z0 + dz)
			edge = g.entities.add_line(p1, p2)
			mat = p[-1]
			extrude_piece(edge, sx, sy, mat)
		end

		#*******************************Materiel***************************************************

		def self.materials
			@materials
		end

		def self.materials=(hash)
			@materials = hash
		end

		def self.load_all_materials_from(folder_name = "materials")
			model = Sketchup.active_model
			mats  = model.materials
			# Chemin absolu du dossier dans le plugin
			base = File.join(__dir__, folder_name)
			unless Dir.exist?(base)
				UI.messagebox("Dossier matériaux introuvable : #{base}")
				return {}
			end
			puts("load matériel: #{folder_name}")
			loaded = {}
			Dir.glob(File.join(base, "*.skm")).each do |file|
				name = File.basename(file, ".skm")
				# Déjà dans le modèle ?
				mat = mats[name]
				if mat
					loaded[name] = mat
					next
				end
				# Sinon on charge
				begin
					mat = mats.load(file)
					loaded[name] = mat if mat
				rescue => e
					puts "Erreur chargement matériau #{file} : #{e}"
				end
			end
			puts("-------------------------------------")
			loaded
		end 
		 
		def self.reappliquer_materiau(lame_group,mat)
			lame_group.entities.grep(Sketchup::Face).each do |f|
				f.material = mat
				f.back_material = mat
			end
		end

		def self.apply_material(ents,material_name=nil,dir=nil)
			return if material_name.nil?
			mats_hash = FctAuvent.materials
			mat = mats_hash[material_name]
			return unless mat
			# Nettoyage + orientation + matériau
			ents.grep(Sketchup::Face).each do |f|
				f.material = nil
				f.back_material = nil
				# Orienter la face vers l'extérieur
				if(dir)
					f.reverse! if f.normal.dot(dir) < 0
				end
				# Appliquer le matériau
				f.material = mat if mat
				f.back_material = mat if mat
			end
		end


		#*********************************Fonctions spécifiques auvent**************************************
		#5 fonctions generate appelées par send(type[:generator] paramétré dans COVER_TYPES

		def self.generate_onduline(root, pts,thickness_i,material,largeur=0,last_component_name=nil)  #edges
			puts("generate_onduline")
			epaisseur = 1.mm
			profil, largeur = profil_onduline_epais(epaisseur)
			z_values = profil.map { |p| p.z }
			zmax = z_values.max + epaisseur 
			pts.map! do |pt|
				Geom::Point3d.new(pt.x, pt.y, pt.z + zmax )   #+ dz  onduline et polycarbonate  rien pour fibrociment -dz/2 pour tuiles canal
			end
			extrude_couverture_ondulée(root, pts, profil, largeur,material)
		end

		def self.generate_polycarbonate(root, pts,thickness_i,material,largeur=0,last_component_name=nil)
			longueur_toit = pts[0].distance(pts[1])
			nb_panneau = (longueur_toit/largeur).floor
			largeur = longueur_toit/nb_panneau
			profil  = profil_polycarbonate_15mm_epais(thickness_i,largeur)	
			z_values = profil.map { |p| p.z }
			zmax = z_values.max	
			pts.map! do |pt|
				Geom::Point3d.new(pt.x, pt.y, pt.z + zmax )   #+ dz  onduline et polycarbonate  rien pour fibrociment -dz/2 pour tuiles canal
			end
			extrude_couverture_ondulée(root, pts, profil, largeur,material,0,0)
		end

		def self.generate_fibrociment(root, pts,thickness_i,material,largeur=0,last_component_name=nil)
			hauteur = 50.mm
			n_ondes = 5
			profil = profil_fibrociment_epais(thickness_i,largeur,hauteur,n_ondes)
			#ajout pour garage pourquoi cette différence ? a voir
			if(last_component_name==nil)
				z_values = profil.map { |p| p.z }
				zmax = z_values.max	
				pts.map! do |pt|
					Geom::Point3d.new(pt.x, pt.y, pt.z + zmax )
				end
			end
			#fin ajout
			extrude_couverture_ondulée(root, pts, profil, largeur,material)
		end

		def self.generate_tuiles_canal(root, pts,thickness_i,material,largeur=0,last_component_name=nil)
			longueur=500.mm   #partie visible
			segments = 12	
			angle=120.degrees
			correction_x_fct_profil=50.mm
			profil = profil_tuiles_canal_epais(thickness_i,largeur,angle,segments)
			if(last_component_name!=nil)
				z_values = profil.map { |p| p.z }
				zmax = z_values.max	
				pts.map! do |pt|
					Geom::Point3d.new(pt.x, pt.y, pt.z - zmax / 2 )   #+ dz  onduline et polycarbonate  rien pour fibrociment -dz/2 pour tuiles canal
				end
			else			#ajout pour garage pourquoi cette différence ? a voir		
				pts.map! do |pt|
					Geom::Point3d.new(pt.x, pt.y, pt.z + 120.mm )   #+ dz  onduline et polycarbonate  rien pour fibrociment -dz/2 pour tuiles canal
				end
			end
			extrude_couverture_ondulée(root, pts, profil, largeur,material,longueur,0,correction_x_fct_profil)
		end

		def self.generate_tuiles_romanes(root, pts,thickness_i,material,largeur,last_component_name=nil)
			longueur=500.mm   #partie visible
			plat = 120.mm
			galbe = 30.mm   #60.mm
			largeur -= 80.mm
			hauteur = 15.mm   #25.mm
			segments = 8	
			profil = profil_tuiles_romanes_epais(thickness_i,plat,galbe,hauteur,segments)
			z_values = profil.map { |p| p.z }
			zmax = z_values.max	
			if(last_component_name!=nil)
				pts.map! do |pt|
					Geom::Point3d.new(pt.x, pt.y, pt.z + zmax / 4 )
				end
			else
				pts.map! do |pt|
					Geom::Point3d.new(pt.x, pt.y, pt.z + zmax + 5.cm  )			#ajout pour garage pourquoi cette différence ? a voir		
				end		
			end
			
			extrude_couverture_ondulée(root, pts, profil, largeur,material,longueur)
		end

		def self.generer_gouttiere(rive,root, layer_auvent,p)
			ep  =  2.mm
			mat = p[-1]
			d=p[1]
			ents = rive.entities
			#  On prend l’arête la plus longue de la rive
			edges = ents.grep(Sketchup::Edge)
			edges_sorted = edges.sort_by { |e| -e.length }
			#  Prendre les 3 longueur(4 edges de chaque longueur)
			longueur_rive = edges_sorted[0].length
			hauteur_rive = edges_sorted[4].length
			epaisseur_rive = edges_sorted[8].length
			# Groupe pour le profil
			model = Sketchup.active_model
			ents  = root.entities
			grp = ents.add_group
			grp.name = "GOUTTIERE"
			grp.layer = root.layer   # hérite automatiquement du layer Auvent
			prof_ents = grp.entities
			#  Centre du profil : devant la rive (vers -X)
			base = edges_sorted[0].start.position
			radius_ext = d / 2
			radius_int = radius_ext - ep
			center = base.offset(Geom::Vector3d.new(0, -(radius_ext + epaisseur_rive), -hauteur_rive/2)) 
			# Profil demi-cercle dans XY
			segments = 16
			pts_ext = []
			(0..segments).each do |i|
				angle = Math::PI * i / segments
				y = center.y + radius_ext * Math.cos(angle)
				z = center.z - radius_ext * Math.sin(angle)
				pts_ext << Geom::Point3d.new(center.x, y, z)
			end
			pts_int = []
			(segments).downto(0) do |i|
				angle = Math::PI * i / segments
				y = center.y + radius_int * Math.cos(angle)
				z = center.z - radius_int * Math.sin(angle)
				pts_int << Geom::Point3d.new(center.x, y, z)  #-30.mm
			end
			if(last_component_name=="AUVENT_GARAGE")
				delete_rive(ents)				#La goutière est fixée sur le fibrociment.
			end
			longueur = edges_sorted[0].length
			contour = pts_ext + pts_int
			contour << pts_ext.first   # fermeture du profil
			face = UtilsAuvent.create_face_oriented(prof_ents, contour, axis: :x, positive: true)
			return unless face
			face.pushpull(longueur)
			first_point_start=pts_int[0]
			last_point_start=pts_int[16]
			first_point_end=first_point_start.clone
			last_point_end=last_point_start.clone
			first_point_end.x += longueur
			last_point_end.x += longueur
			closer = prof_ents.add_line(first_point_start, last_point_start)
			closer.find_faces
			closer = prof_ents.add_line(first_point_end, last_point_end) 
			closer.find_faces 
			grp.material      = mat
			grp
		end

		def self.generer_rives_completes
			model = Sketchup.active_model
			ents  = model.active_entities
			group = ents.grep(Sketchup::Group).last
			return unless group
			gents = group.entities
			chevrons = gents.grep(Sketchup::Group).select { |g| g.name == "CHEVRON" }
			return if chevrons.empty?
			left  = chevrons.min_by { |g| g.bounds.min.x }
			right = chevrons.max_by { |g| g.bounds.max.x }
			[left, right].each do |ch|
				generer_planche_de_rive(ch)
				generer_gouttiere(ch)
			end
		end

		def self.generer_tuiles
			model = Sketchup.active_model
			ents  = model.active_entities
			group = ents.grep(Sketchup::Group).last
			gents = group.entities
			params = PARAMS[:tuile]
			largeur  = params[:largeur]
			hauteur  = params[:hauteur]
			recouv   = params[:recouvrement]
			offset_z = params[:offset_z]
			face = gents.grep(Sketchup::Face).max_by(&:area)
			return unless face
			pts = face.vertices.map(&:position)
			pts_sorted = pts.sort_by { |p| [p.x, p.y] }
			p1, p2, p3, p4 = pts_sorted
			vec_x = p2 - p1
			vec_y = p4 - p1
			longueur  = vec_x.length
			profondeur = vec_y.length
			nx = (longueur / largeur).floor
			ny = (profondeur / (hauteur - recouv)).floor
			tiles_group = gents.add_group
			tiles_group.name=p[0]
			g.layer = model.layer
			tiles = tiles_group.entities
			ny.times do |j|
				offset_x = (j.even? ? 0 : largeur / 2)
				ny_offset = j * (hauteur - recouv)
				nx.times do |i|
					px = i * largeur + offset_x
					next if px + largeur > longueur
					t1 = p1.offset(vec_x, px / longueur).offset(vec_y, ny_offset / profondeur)
					t2 = p1.offset(vec_x, (px + largeur) / longueur).offset(vec_y, ny_offset / profondeur)
					t3 = p1.offset(vec_x, (px + largeur) / longueur).offset(vec_y, (ny_offset + hauteur) / profondeur)
					t4 = p1.offset(vec_x, px / longueur).offset(vec_y, (ny_offset + hauteur) / profondeur)
					z = face.normal
					z.length = offset_z
					t1 += z; t2 += z; t3 += z; t4 += z
					face_t = tiles.add_face(t1, t2, t3, t4)
					face_t.reverse! if face_t.normal.z < 0
					if i.odd?
						mid1 = t1.offset(z, 5.mm)
						mid2 = t2.offset(z, 5.mm)
						tiles.add_face(t1, t2, mid2, mid1)
					end
				end
			end
		end

		def self.generer_rives(root, layer_auvent,p)
			group = root
			return unless group.is_a?(Sketchup::Group)
			gents = group.entities
			edges = gents.grep(Sketchup::Edge)
			chevrons = gents.grep(Sketchup::Group).select { |g| g.name == "CHEVRON" }
			return if chevrons.empty?
			# Détection extrémités en X
			left  = chevrons.min_by { |g| g.bounds.min.x }
			right = chevrons.max_by { |g| g.bounds.max.x }
				#Trouver le chevron le plus bas
			chevron_bas = chevrons.min_by { |g| g.bounds.min.z }
			generer_rive_basse(chevron_bas, left, right,root, layer_auvent,p)
		end

		def self.generer_rive_haute(chevron, sx, sy, mat)
			edges = chevron.entities.grep(Sketchup::Edge)
			edge = edges.max_by { |e| e.bounds.center.z }
			return unless edge
			extrude_piece(edge, sx, sy, mat)
		end

		def self.generer_rive_basse(chevron, left, right,parent, layer_auvent,p)
			sx=p[1]
			sy=p[2]
			mat=p[-1]
			edges = chevron.entities.grep(Sketchup::Edge)
			edges_sorted = edges.sort_by { |e| -e.length }
			# — Prendre les 3 longueur(4 edges de chaque longueur)
			longueur_rive = edges_sorted[0].length
			haut_chevron = edges_sorted[4].length
			ep_chevron = edges_sorted[8].length
			#  Arête basse = position
			edge_base = edges.min_by { |e| e.bounds.center.z }
			return unless edge_base
			# Position globale
			tr = chevron.transformation
			origin = edge_base.start.position.transform(tr)
			# Longueur = distance entre chevrons extrêmes
			longueur = (right.bounds.center.x - left.bounds.center.x + ep_chevron).abs
			# Création du groupe rive
			ents  = parent.entities
			group = ents.add_group
			group.name=p[0]
			group.layer = parent.layer   # sécurité
			gents = group.entities
			# Profil vertical
			v_down = Geom::Vector3d.new(0,0,-1)
			v_x    = Geom::Vector3d.new(1,0,0)
			p1 = origin.offset(v_x, 0)  #en x-60.mm
			p2 = p1.offset(v_down, sy)
			p3 = p2.offset(v_x, sx)
			p4 = p1.offset(v_x, sx)
			#  Transformation à appliquer AVANT création de la face
			pivot = p2
			tr_rot = Geom::Transformation.rotation(
			pivot,
			Geom::Vector3d.new(0,0,1),
			90.degrees
			)
			if(last_component_name=="AUVENT_GARAGE")
				longueur += 2 * (280.mm+150.mm)-80.mm      #debord chevrons(liteaux dans ce cas)+debord couverture
				tr_offset = Geom::Transformation.translation(
					Geom::Vector3d.new(-280.mm-80.mm-150.mm, -sx, sy + haut_chevron )
				)
			else
				tr_offset = Geom::Transformation.translation(
					Geom::Vector3d.new(0, -sx, sy + haut_chevron - 170.mm)    #
				)
			end
			# Appliquer transformation aux 4 points
			p1t = p1.transform(tr_rot).transform(tr_offset)
			p2t = p2.transform(tr_rot).transform(tr_offset)
			p3t = p3.transform(tr_rot).transform(tr_offset)
			p4t = p4.transform(tr_rot).transform(tr_offset)
			# Créer la face dans le bon repère
			face = gents.add_face(p1t, p2t, p3t, p4t)
			# Extrusion dans le bon repère
			face.pushpull(longueur)
			# Matériau
			group.material = mat
			group.name = "RIVE_BASSE"
			group.layer = parent.layer
			group
		end

		def self.generate_liteaux_sur_chevrons(parent, nb_liteaux = 3, section = [30.mm, 30.mm],material_name=nil)    #parent, section, entraxe
			ents = parent.entities
			# --- Récupération des chevrons ---
			chevrons = ents.select { |e| e.is_a?(Sketchup::Group) && e.name == "CHEVRON" }
			return if chevrons.length < 2
			# --- Chevron de référence ---
			chevron_ref = chevrons.first
			edge_ref = UtilsAuvent.axis_edge_of(chevron_ref)
			cotes_chevron=section_chevron(chevron_ref)
			hauteur_chevron=cotes_chevron[:hauteur].mm 
			largeur_chevron=cotes_chevron[:largeur].mm 
			longueur_chevron=cotes_chevron[:longueur].mm 
			# Points du chevron en MONDE
			p1 = chevron_ref.transformation * edge_ref.start.position
			p2 = chevron_ref.transformation * edge_ref.end.position
			# --- Direction du chevron (dans YZ, pente) ---
			dir_chevron = (p2 - p1)
			dir_chevron.length = 1.0
			# --- Direction du liteau = X global (perpendiculaire aux chevrons) ---
			dir_liteau = Geom::Vector3d.new(1, 0, 0)
				# --- Normale du toit = chevron × liteau ---
			normal_toit = dir_chevron * dir_liteau
			normal_toit.length = 1.0
			normal_toit.reverse! if normal_toit.z < 0  # on force vers Z+
			def self.x_center(g)
				bb = g.bounds
				(bb.min.x + bb.max.x) / 2.0
			end
			g1 = chevrons.min_by { |g| x_center(g) }
			g2 = chevrons.max_by { |g| x_center(g) }
			offset_dist = hauteur_chevron   
			positions = []
			if(last_component_name=="AUVENT_GARAGE")
				depassement = 280.mm
				len_liteau = largeur_chevron + (x_center(g2) - x_center(g1)).abs
				return if len_liteau <= 0.1.mm 
				len_liteau += depassement * 2
				offset_dist -= hauteur_chevron
				base = p1.offset(normal_toit, offset_dist)
				(0...nb_liteaux).each do |i|
					positions << ((longueur_chevron-section[1]-230.mm) * (i.to_f / (nb_liteaux - 1))+230.mm)  #20mm corriger avec la pente dû à la coupe
				end
			else
				len_liteau = largeur_chevron + (x_center(g2) - x_center(g1)).abs
				return if len_liteau <= 0.1.mm 
				base = p1.offset(normal_toit, offset_dist)
				# --- Calcul des positions des liteaux selon nb_liteaux ---
				(0...nb_liteaux).each do |i|
					positions << ((longueur_chevron-section[1]) * (i.to_f / (nb_liteaux - 1))+section[1]-20.mm)  #20mm corriger avec la pente dû à la coupe
				end
			end
			nb_liteaux.times do |i|
				pos = base.offset(dir_chevron, positions[i])
				# lignes décalage liteau vers -x de ep_chevron
				v_back = dir_liteau.clone
				v_back.reverse!
				#add this line for barbuc	
				#pos = pos.offset(v_back, 590.mm)
				# section dans YZ local
				p0s = Geom::Point3d.new(0, 0, 0)
				p1s = Geom::Point3d.new(0, section[1], 0)
				p2s = Geom::Point3d.new(0, section[1], section[0])
				p3s = Geom::Point3d.new(0, 0, section[0])
				# Transformation à appliquer AVANT création
				xaxis = dir_liteau      # longueur du liteau (X)
				yaxis = dir_chevron     # le long du chevron
				zaxis = normal_toit     # vers l’extérieur du toit
				if(last_component_name=="AUVENT_GARAGE")
					v_dep = dir_liteau.clone
					v_dep.length = depassement+80.mm   #section chevron
					pos -= v_dep
				end  
				tr = Geom::Transformation.axes(pos, xaxis, yaxis, zaxis)
				#Appliquer transformation aux points
				p1t = p0s.transform(tr)
				p2t = p1s.transform(tr)
				p3t = p2s.transform(tr)
				p4t = p3s.transform(tr)
				# Créer le groupe SANS transformation
				g = parent.entities.add_group
				gents = g.entities
				g.name = "LITEAU"                     # a voir
				g.layer = parent.layer
				# Créer la face dans le bon repère
				face = gents.add_face(p1t, p2t, p3t, p4t)
				# Extrusion dans le bon repère
				face.pushpull(len_liteau)
				g.set_attribute("auvent", "tr", g.transformation.to_a)
				apply_material(g.entities,material_name,dir_liteau)
			end
		end

		def self.generer_cutter_depuis_repere(lame_group,tr_plane,zaxis)
			# Créer le cutter dans la LAME (pas dans le modèle)
			cutter_group = lame_group.entities.add_group
			cutter_group.name = "CUTTER_LOCAL_REPERE"
			size = 5000.mm
			pts_local = [
				Geom::Point3d.new(-size, -size, 0),
				Geom::Point3d.new( size, -size, 0),
				Geom::Point3d.new( size,  size, 0),
				Geom::Point3d.new(-size,  size, 0)
			]
			if(last_component_name=="AUVENT_GARAGE")	#cas particulier:les chevrons sont en réalité des liteaux pour poser le toit dessus
				tr_rotX = Geom::Transformation.rotation(ORIGIN, X_AXIS, -90.degrees)
				tr_offset_local = Geom::Transformation.translation([0, 0, 200.mm])
				# Points dans l’espace global du chevron
				pts_world = pts_local.map { |p| p.transform(tr_plane*tr_rotX*tr_offset_local) }
			else
				pts_world = pts_local.map { |p| p.transform(tr_plane) }
			end
			# Ramener dans l’espace local de la lame
			pts_lame = pts_world.map { |p| p.transform(lame_group.transformation.inverse) }
			cutter_face = cutter_group.entities.add_face(pts_lame)
			# Forcer la normale dans le sens du haut
			if cutter_face.normal.dot(zaxis) < 0
				cutter_face.reverse!
			end
			# Couper la partie haute du lambris changer de signe pour la partie basse
			cutter_face.pushpull(-1.mm)
			return cutter_group
		end

		def self.debord_toit_fct_liteaux(pts,debords: {})
			#           haut
			#         p4     p3
			# gauche  p1     p2   droite
			#             bas
			p1, p2, p3, p4 = pts
			g = debords.fetch(:gauche, 0.mm)  #0 valeur par defaut
			d = debords.fetch(:droite, 0.mm)
			h = debords.fetch(:haut,   0.mm)
			b = debords.fetch(:bas,    0.mm)
			p1.x=p1.x-g
			p4.x=p4.x-g
			p3.x=p3.x+d
			p2.x=p2.x+d  
			angle_rad=detect_pente_toit_from_pts_rd(pts) 
			dyb=b*Math.cos(angle_rad)
			dzb=b*Math.sin(angle_rad)
			p1.y=p1.y-dyb 
			p2.y=p2.y-dyb
			p1.z=p1.z-dzb 
			p2.z=p2.z-dzb
			dyh=h*Math.cos(angle_rad)
			dzh=h*Math.sin(angle_rad) 
			p3.z=p3.z+dzh 
			p4.z=p4.z+dzh  
			p3.y=p3.y+dyh 
			p4.y=p4.y+dyh  
			pts = [p1, p2, p3, p4].uniq
		end

		def self.detect_pente_toit_from_pts_rd(pts)      # voir detect_pente_toit_from_pts_rd_1 pb float ?
			# On prend un point bas et un point haut
			bas  = pts.min_by(&:z)
			haut = pts.max_by(&:z)
			v = bas.vector_to(haut)
			Math.atan2(v.z,  v.y) #* 180 / Math::PI
		end

		def self.detect_edges_couverture(grp)
			ents = grp.entities
			# Récupérer toutes les arêtes horizontales
			edges = ents.grep(Sketchup::Edge).select { |e|
				vec = e.line[1]
				vec.parallel?(Geom::Vector3d.new(1,0,0)) ||
				vec.parallel?(Geom::Vector3d.new(0,1,0))
			}
			if edges.length < 2
				UI.messagebox("Impossible de détecter les arêtes du toit.")
				return nil
			end
			# Trier par longueur (les plus longues = arêtes du toit)
			edges_sorted = edges.sort_by { |e| -e.length }
			# Prendre les deux plus longues
			edge1 = edges_sorted[0]
			edge2 = edges_sorted[1]
			# Vérifier qu'elles sont parallèles
			unless edge1.line[1].parallel?(edge2.line[1])
				UI.messagebox("Les arêtes détectées ne sont pas parallèles.")
				return nil
			end
			[edge1, edge2]
		end

		def self.generer_gouttieres(root, layer_auvent, p)
			rive = trouver_rives_basses(root)
			return unless rive
			generer_gouttiere(rive,root, layer_auvent,p)
		end

		def self.genere_profils_lamelles(pts_profil_lambris_world,nb_lamelle_par_lame,debug)
			#pts_profil_lambris_world
			#		5-----------4
			# 6						3
			# |                     |
			# 7						2
			#		0-----------1  ----------------->X
			largeur=(pts_profil_lambris_world[2].x-pts_profil_lambris_world[7].x)
			x= largeur/4
			x1=largeur/2
			x2= 3*largeur/4
			points_lamelles = Array.new(nb_lamelle_par_lame) { [] }
			(0..nb_lamelle_par_lame-1).each do |i|
				if(i==0 )    #   coté gauche lambris
					points_lamelles[i] << pts_profil_lambris_world[0]
					points_lamelles[i] <<           Geom::Point3d.new(pts_profil_lambris_world[6].x + x, pts_profil_lambris_world[0].y, pts_profil_lambris_world[0].z)   #pts_profil_lambris_world[0]
					points_lamelles[i] <<           Geom::Point3d.new(pts_profil_lambris_world[7].x + x, pts_profil_lambris_world[5].y, pts_profil_lambris_world[5].z)   #pts_profil_lambris_world[5]
					points_lamelles[i] << pts_profil_lambris_world[5]
					points_lamelles[i] << pts_profil_lambris_world[6]
					points_lamelles[i] << pts_profil_lambris_world[7]
				elsif(i==1 )#   rectangle
					points_lamelles[i] << Geom::Point3d.new(pts_profil_lambris_world[6].x + x, pts_profil_lambris_world[0].y, pts_profil_lambris_world[0].z)   #pts_profil_lambris_world[0]                 #Geom::Point3d.new(x, offset.y, z - 1.mm)
					points_lamelles[i] << Geom::Point3d.new(pts_profil_lambris_world[7].x + x, pts_profil_lambris_world[5].y, pts_profil_lambris_world[5].z)   #pts_profil_lambris_world[5]                 #x, offset.y + epaisseur_lames, z - 1.mm
					points_lamelles[i] << Geom::Point3d.new(pts_profil_lambris_world[7].x + x1, pts_profil_lambris_world[5].y, pts_profil_lambris_world[5].z)   #pts_profil_lambris_world[5]
					points_lamelles[i] << Geom::Point3d.new(pts_profil_lambris_world[6].x + x1, pts_profil_lambris_world[0].y, pts_profil_lambris_world[0].z)   #pts_profil_lambris_world[0]
				elsif(i==2)#  rectangle
					points_lamelles[i] << Geom::Point3d.new(pts_profil_lambris_world[6].x + x1, pts_profil_lambris_world[0].y, pts_profil_lambris_world[0].z)   #pts_profil_lambris_world[0]                 #Geom::Point3d.new(x, offset.y, z - 1.mm)
					points_lamelles[i] << Geom::Point3d.new(pts_profil_lambris_world[7].x + x1, pts_profil_lambris_world[5].y, pts_profil_lambris_world[5].z)   #pts_profil_lambris_world[5]                 #x, offset.y + epaisseur_lames, z - 1.mm
					points_lamelles[i] << Geom::Point3d.new(pts_profil_lambris_world[7].x + x2, pts_profil_lambris_world[5].y, pts_profil_lambris_world[5].z)   #pts_profil_lambris_world[5]
					points_lamelles[i] << Geom::Point3d.new(pts_profil_lambris_world[6].x + x2, pts_profil_lambris_world[0].y, pts_profil_lambris_world[0].z)   #pts_profil_lambris_world[0]
				elsif(i==3 )#	coté droit lambris
					points_lamelles[i] << pts_profil_lambris_world[1]
					points_lamelles[i] << pts_profil_lambris_world[2]
					points_lamelles[i] << pts_profil_lambris_world[3]
					points_lamelles[i] << pts_profil_lambris_world[4]
					points_lamelles[i] << Geom::Point3d.new(pts_profil_lambris_world[6].x + x2, pts_profil_lambris_world[5].y, pts_profil_lambris_world[5].z)   #pts_profil_lambris_world[5]
					points_lamelles[i] << Geom::Point3d.new(pts_profil_lambris_world[7].x + x2, pts_profil_lambris_world[0].y, pts_profil_lambris_world[0].z)   #pts_profil_lambris_world[0]
				end
			end	
			return points_lamelles
		end

		def self.generer_tuiles
			model = Sketchup.active_model
			ents  = model.active_entities
			group = ents.grep(Sketchup::Group).last
			gents = group.entities
			params = PARAMS[:tuile]
			largeur  = params[:largeur]
			hauteur  = params[:hauteur]
			recouv   = params[:recouvrement]
			offset_z = params[:offset_z]
			face = gents.grep(Sketchup::Face).max_by(&:area)
			return unless face
			pts = face.vertices.map(&:position)
			pts_sorted = pts.sort_by { |p| [p.x, p.y] }
			p1, p2, p3, p4 = pts_sorted
			vec_x = p2 - p1
			vec_y = p4 - p1
			longueur  = vec_x.length
			profondeur = vec_y.length
			nx = (longueur / largeur).floor
			ny = (profondeur / (hauteur - recouv)).floor
			tiles_group = gents.add_group
			tiles = tiles_group.entities
			ny.times do |j|
				offset_x = (j.even? ? 0 : largeur / 2)
				ny_offset = j * (hauteur - recouv)
				nx.times do |i|
					px = i * largeur + offset_x
					next if px + largeur > longueur
					t1 = p1.offset(vec_x, px / longueur).offset(vec_y, ny_offset / profondeur)
					t2 = p1.offset(vec_x, (px + largeur) / longueur).offset(vec_y, ny_offset / profondeur)
					t3 = p1.offset(vec_x, (px + largeur) / longueur).offset(vec_y, (ny_offset + hauteur) / profondeur)
					t4 = p1.offset(vec_x, px / longueur).offset(vec_y, (ny_offset + hauteur) / profondeur)
					z = face.normal
					z.length = offset_z
					t1 += z; t2 += z; t3 += z; t4 += z
					face_t = tiles.add_face(t1, t2, t3, t4)
					face_t.reverse! if face_t.normal.z < 0
					if i.odd?
						mid1 = t1.offset(z, 5.mm)
						mid2 = t2.offset(z, 5.mm)
						tiles.add_face(t1, t2, mid2, mid1)
					end
				end
			end
		  end

		def self.generate_chevrons_sur_poutres(parent, nb_chevrons = 3, section = [35.mm, 70.mm], dep_y = 0.mm, material_name = nil)
			ents = parent.entities
			# --- Récupérer les poutres ---
			poutres = ents.grep(Sketchup::Group).select { |g| g.name == "POUTRE" }
			return if poutres.length < 2
			# --- Direction horizontale de la poutre ---
			edge_ref = UtilsAuvent.long_edge_of(poutres.first)
			p1 = edge_ref.start.position
			p2 = edge_ref.end.position
			dir_poutre = (p2 - p1)
			dir_poutre.z = 0
			dir_poutre.length = 1.0
			# --- Direction horizontale perpendiculaire (base du chevron) ---
			dir_horiz = Geom::Vector3d.new(-dir_poutre.y, dir_poutre.x, 0)
			dir_horiz.length = 1.0
			# --- Trier les poutres selon dir_horiz ---
			proj = ->(g) {
				g.bounds.center.to_a.zip(dir_horiz.to_a).map { |a,b| a*b }.inject(0, :+)
			}
			poutres_sorted = poutres.sort_by { |g| proj.call(g) }
			poutre_avant = poutres_sorted.first
			poutre_arriere = poutres_sorted.last
			# --- Points extrêmes pour calculer la pente réelle ---
			edge_Av = UtilsAuvent.long_edge_of(poutre_avant)   #Gauche avant
			edge_Ar = UtilsAuvent.long_edge_of(poutre_arriere)
			edge_short_Av=UtilsAuvent.short_edge_of(poutre_avant).length
			edge_short_Ar=UtilsAuvent.short_edge_of(poutre_arriere).length  
			delta=(edge_short_Ar-edge_short_Av)/2
			pG = edge_Av.start.position
			pD = edge_Ar.start.position
			# --- Calcul de la pente réelle ---
			dz = (pD.z - pG.z)   #+45.mm
			dx = (pD - pG).length   
			dy = pD.y-pG.y + edge_short_Ar  #
			pente_rad = Math.atan2(dz, dy)   #angles extérieures et supérieurs
			# --- Direction inclinée du chevron ---
			dir_chevron = Geom::Vector3d.new(dir_horiz.x, dir_horiz.y, Math.tan(pente_rad))
			dir_chevron.length = 1.0
			# --- Verticale locale ---
			dir_z = dir_chevron * dir_poutre
			dir_z.length = 1.0
			# --- Longueur du chevron (distance entre poutres) ---
			#distance horizontal d'axe à axe
			distance_horizontal = (proj.call(poutre_arriere) + proj.call(poutre_avant)).abs
			distance_horizontal+=(dep_y + delta-40.mm)      #-74.mm)  
			# --- Longueur de la poutre (pour répartir les chevrons) ---
			edge_long = UtilsAuvent.long_edge_of(poutre_avant)
			len_poutre = edge_long.length
			# --- Positions des chevrons le long de la poutre ---
			positions = []
			(0..(nb_chevrons - 1)).each do |i|
				positions << ((len_poutre - section[1] ) * i.to_f / (nb_chevrons - 1))    #60.mm
			end
			positions.each do |dist|
				# Position le long de la poutre
				vprog = dir_poutre.clone
				vprog.length = dist
				pos = p1.offset(vprog)
				# Centrage sur l'épaisseur
				v_center = dir_horiz.clone
				pos += v_center
				# --- Création du groupe CHEVRON ---
				g = creer_chevron(
				parent,
				distance_horizontal,
				section[0],
				section[1],
				pente_rad,
				dep_y,
				pos.x ,
				pG.z )	#pos.z
				apply_material(g.entities, material_name, dir_chevron) if material_name
			end
		end

		def self.get_chevrons_group(ossature_group)
			chevrons = ossature_group.entities.grep(Sketchup::Group).select { |g|
				g.name.include?("CHEVRON")
			}
			return chevrons
		end

		def self.get_ossature_group()
			model = Sketchup.active_model
			comp_name = FctAuvent.last_component_name
			auvent_def = model.definitions[comp_name]
			if auvent_def.nil?
				UI.messagebox("Le composant '#{comp_name}' n'existe plus dans le modèle.")
			end
			ossature_group = UtilsAuvent.get_ossature_group(auvent_def)
		end

		def self.chevron_le_plus_proche(lame_group, chevrons)
			lambris_center = lame_group.bounds.center
			chevrons.min_by do |ch|
				d = ch.bounds.center.distance(lambris_center)
				d
			end
		end

		def self.lire_fichier_ossature(path)
			lignes = File.readlines(path, chomp: true)
			pieces = []
			vars = {}
			lignes.each do |ligne|
				# Retirer les commentaires
				ligne = ligne.split("#").first.to_s.strip
				next if ligne.empty?
				# Ignorer les sections [xxx]
				next if ligne =~ /^\[.*\]$/
				# Définition de variable : VAR = valeur
				#if ligne =~ /^([A-Z][A-Z0-9_]*)\s*=\s*(.+)$/   pas de minuscule
				#if ligne =~ /^([A-Za-z_]+)\s*=\s*(.+)$/		pas de chiffre
				if ligne =~ /^([A-Za-z0-9_]+)\s*=\s*(.+)$/
				vars[$1] = UtilsAuvent.eval_expr($2, vars)
				next
			end
			# Découper la ligne
			parts = ligne.split(";").map(&:strip)
			# --- Détection du matériau AVANT toute évaluation ---
			material = nil
			if parts.last =~ /^MAT=(.+)$/i
				material = $1.strip
				parts.pop
			end
			# Type de pièce
			type = parts[0]
			puts "DEBUG type = #{type.inspect}"
			raw_values = parts[1..-1].map { |p| UtilsAuvent.eval_expr(p, vars) }
			case type
				when "LAMBRIS","CLINS"
					# On NE passe PAS direction/orientation dans eval_expr
					x         = UtilsAuvent.eval_expr(parts[1], vars).mm
					y         = UtilsAuvent.eval_expr(parts[2], vars).mm
					z         = UtilsAuvent.eval_expr(parts[3], vars).mm
					largeur   = UtilsAuvent.eval_expr(parts[4], vars).mm
					hauteur   = UtilsAuvent.eval_expr(parts[5], vars).mm
					direction   = parts[6].to_s.strip.downcase.to_sym
					orientation = parts[7].to_s.strip.downcase.to_sym
					pas         = UtilsAuvent.eval_expr(parts[8], vars).mm
					epaisseur  = UtilsAuvent.eval_expr(parts[9], vars).mm
					delta_hauteur = UtilsAuvent.eval_expr(parts[10], vars).mm
					id = parts[11].to_s.strip.downcase.to_sym
					pieces << [type, x, y, z, largeur, hauteur, direction, orientation, pas, epaisseur,delta_hauteur,id , material]
				next   #next line ?
				when "CUTTER"
					 #CUTTER;x1;y1;z1;x2;y2;z2;x3;y3;z3;x4;y4;z4;direction;objet 
					 #4 point + 1 direction, supprime la partie vers direction;objet= clin,lambris...	
					x1         = UtilsAuvent.eval_expr(parts[1], vars).mm
					y1         = UtilsAuvent.eval_expr(parts[2], vars).mm
					z1         = UtilsAuvent.eval_expr(parts[3], vars).mm			 
					x2         = UtilsAuvent.eval_expr(parts[4], vars).mm
					y2         = UtilsAuvent.eval_expr(parts[5], vars).mm
					z2         = UtilsAuvent.eval_expr(parts[6], vars).mm						 
					x3         = UtilsAuvent.eval_expr(parts[7], vars).mm
					y3         = UtilsAuvent.eval_expr(parts[8], vars).mm
					z3         = UtilsAuvent.eval_expr(parts[9], vars).mm	
					x4         = UtilsAuvent.eval_expr(parts[10], vars).mm
					y4         = UtilsAuvent.eval_expr(parts[11], vars).mm
					z4         = UtilsAuvent.eval_expr(parts[12], vars).mm	
					direction   = parts[13].to_s.strip.downcase.to_sym
					id   = parts[14].to_s.strip.downcase.to_sym			
					pieces << [type, x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4, direction,id]
				next   #next line ?
			end
			values = parts[1..-1].map { |p| UtilsAuvent.eval_expr(p, vars) }   
			case type	
				when "LITEAU"
					values = [
						raw_values[0],          # nombre → pas en mm
						raw_values[1].mm,       # section X
						raw_values[2].mm,       # section Y
					]
				when "CHEVRON"
					values = [
						raw_values[0],      # nombre
						raw_values[1].mm,   # section X
						raw_values[2].mm,   # section Y
						raw_values[3].mm,   # dépassement	
					]
				else
					# par défaut : tout en mm
					values = raw_values.map { |v| v.mm }
				end
				# Ajouter la pièce complète
				pieces << [type, *values, material]
			end   #lignes.each do |ligne|
			{ pieces: pieces, vars: vars }
		end

		def self.debug_chevron(chevron)
		  puts "=============================="
		  puts "   DEBUG CHEVRON : #{chevron.name}"
		  puts "=============================="
		  bb = chevron.bounds
		  puts "Bounds:"
		  puts "  min: #{bb.min}"
		  puts "  max: #{bb.max}"
		  puts "  center: #{bb.center}"
		  # Arêtes
		  edges = chevron.entities.grep(Sketchup::Edge)
		  puts "Nombre d'arêtes : #{edges.length}"
		  # Arête la plus haute
		  top_edge = edges.max_by { |e| e.bounds.center.z }
		  puts "Arête haute : #{top_edge.start.position} -> #{top_edge.end.position}"
		  # Arête la plus basse
		  bottom_edge = edges.min_by { |e| e.bounds.center.z }
		  puts "Arête basse : #{bottom_edge.start.position} -> #{bottom_edge.end.position}"
		  # Highlight visuel (optionnel)
		  begin
			chevron.material = "red"   # ??
			puts "Chevron coloré en rouge pour debug."
		  rescue
			puts "Impossible de colorer le chevron."
		  end
		  puts "=============================="
		end

		def self.trouver_rives_basses(root)
			return nil unless root.is_a?(Sketchup::Group)
			rives_basses = root.entities.grep(Sketchup::Group).find { |g| g.name == "RIVE_BASSE"  && g.valid? }
		end

		def self.get_chevron_faces(chevron_group)
			faces = []
			chevron_group.entities.each do |e|
				if e.is_a?(Sketchup::Face)
					faces << e
				elsif e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
					faces.concat(self.get_chevron_faces(e))
				end
			end
			faces
		end

		def self.chevron_pour_lame(lame_group, chevrons)
			return nil if chevrons.empty?
			ch = chevron_le_plus_proche(lame_group, chevrons)
			ch
		end

		def self.coupe_lambris_sur_chevron(lame_group, chevron_group,cas=0)
			plan = plan_depuis_chevron(chevron_group)
			return unless plan
			cutter_group = generer_cutter_depuis_repere(lame_group,plan[:tr_plane],plan[:zaxis])
			coupe_solide_clins(lame_group, cutter_group)
			cutter_group.erase!
		end

		def self.plan_depuis_chevron(chevron_group)
			#  Récupérer toutes les faces du chevron (récursif)
			faces = []
			stack = [chevron_group]
			until stack.empty?
				g = stack.pop
				g.entities.each do |e|
					if e.is_a?(Sketchup::Face)
						faces << e
					elsif e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
						stack << e
					end
				end
			end
			#  Filtrer les faces inclinées (ni horizontales ni verticales)
			inclined = faces.select { |f|
				nz = f.normal.z
				nz.abs > 0.01 && nz.abs < 0.99
			}
			return nil if inclined.empty?
			#  Face du dessus = inclinée avec la plus grande moyenne de Z
			top_face = inclined.max_by do |f|
				verts = f.vertices.map(&:position)
				sum_z = verts.inject(0.0) { |s, p| s + p.z }
				sum_z / verts.length.to_f
			end
			# Faces parallèles à la face du dessus
			parallel = faces.select { |f| f.normal.parallel?(top_face.normal) }
			#  Face du dessous = parallèle avec la plus petite moyenne de Z
			bottom_face = parallel.min_by do |f|
				verts = f.vertices.map(&:position)
				sum_z = verts.inject(0.0) { |s, p| s + p.z }
				sum_z / verts.length.to_f
			end
			ch_face = bottom_face
			#  Construire le repère sur la face du dessous
			p1 = ch_face.vertices[0].position
			p2 = ch_face.vertices[1].position
			xaxis = (p2 - p1).normalize
			zaxis = ch_face.normal.normalize
			yaxis = zaxis.cross(xaxis).normalize
			tr_plane = Geom::Transformation.axes(p1, xaxis, yaxis, zaxis)
			{
				p1: p1,
				xaxis: xaxis,
				yaxis: yaxis,
				zaxis: zaxis,
				tr_plane: tr_plane
			}
		end

		def self.coupe_lambris_sur_points(lame_group, pts,normal: :zminus)
			p1, p2, p3, p4 = pts
			# --- 1) Construire un repère à partir des 3 premiers points
			xaxis = (p2 - p1).normalize
			zaxis = (p2 - p1).cross(p3 - p1)
			return if zaxis.length < 1e-6 # points alignés
			zaxis.normalize!
			yaxis = zaxis.cross(xaxis).normalize
			tr_plane = Geom::Transformation.axes(p1, xaxis, yaxis, zaxis)
			# --- 2) Générer le cutter
			cutter_group = lame_group.entities.add_group
			cutter_group.name = "CUTTER_LOCAL_PTS"
			size = 5000.mm
			pts_local = [
				Geom::Point3d.new(-size, -size, 0),
				Geom::Point3d.new( size, -size, 0),
				Geom::Point3d.new( size,  size, 0),
				Geom::Point3d.new(-size,  size, 0)
		  ]
			pts_world = pts_local.map { |p| p.transform(tr_plane) }
			pts_lame  = pts_world.map { |p| p.transform(lame_group.transformation.inverse) }
			cutter_face = cutter_group.entities.add_face(pts_lame)
			case normal
				when :zminus
					# Normale vers le bas supression de la partie basse
					cutter_face.reverse! if cutter_face.normal.dot(zaxis) > 0
				when :zplus
					# Normale vers le haut  supression de la partie haute
					cutter_face.reverse! if cutter_face.normal.dot(zaxis) < 0
				end
			cutter_face.pushpull(-1.mm)
			coupe_solide_clins(lame_group, cutter_group)
			cutter_group.erase!
		end

		def self.face_inclinee_du_chevron(chevron_group)
			faces = chevron_group.entities.grep(Sketchup::Face)
			# La face inclinée est celle dont la normale n’est ni horizontale ni verticale
			faces.find do |f|
				n = f.normal
				n.z.abs < 0.99 && n.x.abs < 0.99  # normale inclinée
			end
		end

		def self.trouver_chevrons(obj)
			resultat = []
			if obj.is_a?(Sketchup::Group) || obj.is_a?(Sketchup::ComponentInstance)
				ents = obj.entities
				resultat += ents.grep(Sketchup::Group).select { |g| g.name.to_s.upcase.include?("CHEVRON") }
				ents.grep(Sketchup::Group).each { |g| resultat += trouver_chevrons(g) }
			end
			resultat
		end

		def self.coupe_solide_clins(target_group, cutter_group)
			ents = target_group.entities
			tr_target  = target_group.transformation
			tr_cutter  = cutter_group.transformation
			# Face du cutter ---
			cutter_face = cutter_group.entities.grep(Sketchup::Face).first
			return unless cutter_face
			plane_point  = cutter_face.vertices.first.position.transform(tr_cutter)
			plane_normal = cutter_face.normal.transform(tr_cutter)
			plane_normal.normalize!
			#  Intersection ---
			ents.intersect_with(true, IDENTITY, ents, IDENTITY, true, cutter_group)
			#  Supprimer les faces du mauvais côté ---
			faces_to_delete = []
			ents.grep(Sketchup::Face).each do |f|
				p_local  = f.vertices.first.position
				p_global = p_local.transform(tr_target)
				if UtilsAuvent.point_side(p_global, plane_point, plane_normal) > 0
					faces_to_delete << f
				end
			end
			faces_to_delete.each(&:erase!)
				#  Supprimer les edges orphelins OU du mauvais côté ---
				edges_to_delete = []
				ents.grep(Sketchup::Edge).each do |e|
					# Edge orphelin → à supprimer
					if e.faces.empty?
						edges_to_delete << e
					next
				end
				# Edge du mauvais côté → supprimer faces + edge
				p_local  = e.start.position
				p_global = p_local.transform(tr_target)
				if UtilsAuvent.point_side(p_global, plane_point, plane_normal) > 0
					e.faces.each(&:erase!)
					edges_to_delete << e
				end
			end
			edges_to_delete.each do |e|
				next unless e.valid? && !e.deleted?
				e.erase!
			end
			#  Nettoyage final ---
			ents.grep(Sketchup::Face).each { |f| f.erase! if f.vertices.empty? }
			ents.grep(Sketchup::Edge).each { |e| e.erase! if e.faces.empty? }
			ents.grep(Sketchup::Vertex).each { |v| v.erase! if v.edges.empty? }
		end
		
		def self.chanfrein_rect_horizontal_su2017(face, retrait, profondeur)
			ents = face.parent.entities
			pts  = face.outer_loop.vertices.map(&:position)
			xs = pts.map(&:x)
			ys = pts.map(&:y)
			z  = pts.first.z
			xmin, xmax = xs.min, xs.max
			ymin, ymax = ys.min, ys.max
			# points extérieurs (ordre horaire)
			p1 = Geom::Point3d.new(xmin, ymin, z)
			p2 = Geom::Point3d.new(xmax, ymin, z)
			p3 = Geom::Point3d.new(xmax, ymax, z)
			p4 = Geom::Point3d.new(xmin, ymax, z)
			# points chanfreinés (retrait + descente)
			q1 = Geom::Point3d.new(xmin + retrait, ymin + retrait, z - profondeur)
			q2 = Geom::Point3d.new(xmax - retrait, ymin + retrait, z - profondeur)
			q3 = Geom::Point3d.new(xmax - retrait, ymax - retrait, z - profondeur)
			q4 = Geom::Point3d.new(xmin + retrait, ymax - retrait, z - profondeur)
			# on supprime la face d'origine
			face.erase!
			# on trace les 4 faces de chanfrein avec ta méthode "bouchon"
			[[p1,p2,q2,q1],
			[p2,p3,q3,q2],
			[p3,p4,q4,q3],
			[p4,p1,q1,q4]].each do |a,b,c,d|
				e1 = ents.add_line(a, b)
				e2 = ents.add_line(b, c)
				e3 = ents.add_line(c, d)
				e4 = ents.add_line(d, a)
				e4.find_faces
			end
			# --- Création de la face intérieure (méthode bouchon) ---
			e1 = ents.add_line(q1, q2)
			e2 = ents.add_line(q2, q3)
			e3 = ents.add_line(q3, q4)
			e4 = ents.add_line(q4, q1)
			e4.find_faces
		end

		def self.creer_chevron(parent,distance_horizontal,hauteur,epaisseur,pente_rad,debord,posx,posz)	
			#pos_z dessus de la poutre du bas
			g = parent.entities.add_group
			g.name = "CHEVRON"
			g.layer = parent.layer
			ge = g.entities
			# Section locale : X = direction chevron, Y = direction poutre
			longueur = distance_horizontal/Math.cos(pente_rad)
			pos_y =distance_horizontal-debord
			#pos_y=(;ongueur-debord*Math.tan(pente_rad))*Math.cos(pente_rad)
			#longeur_horizontale_debord=debord*Math.tan(pente_rad)
			hauteur_vertical_chevron=hauteur/Math.cos(pente_rad)
			cor_vertical_debord = debord * Math.tan(pente_rad)   #debord/Math.cos(pente_rad)
			pos_z_1=posz-cor_vertical_debord
			pos_z_2=pos_z_1+longueur*Math.sin(pente_rad)
			pos_z_3=pos_z_2+hauteur_vertical_chevron	
			pos_z_4=pos_z_1+hauteur_vertical_chevron	
			p1=Geom::Point3d.new(posx, -debord, pos_z_1)
			p2=	Geom::Point3d.new(posx,  pos_y, pos_z_2)
			p3=Geom::Point3d.new(posx, pos_y,  pos_z_3)
			p4=Geom::Point3d.new(posx,-debord  ,  pos_z_4)
			face = ge.add_face(
				p1,
				p2,
				p3,
				p4
			)
			face.pushpull(epaisseur)
			return g
		end

		def self.delete_liteaux(gents)
			liteaux = gents.grep(Sketchup::Group).select { |g| g.name == "LITEAU" }
			liteaux.each(&:erase!)
		end

		def self.delete_rive(gents)
			rive = gents.grep(Sketchup::Group).select { |g| g.name == "RIVE_BASSE" }
			rive.each(&:erase!)
		end

		def self.section_chevron(chevron_group)
			ents = chevron_group.entities
			edges = ents.grep(Sketchup::Edge)
			# On récupère les longueurs uniques
			lengths = edges.map { |e| e.length.to_mm }.uniq.sort
			largeur  = lengths[0]
			hauteur  = lengths[1]
			longueur = lengths[2]
			{ largeur: largeur, hauteur: hauteur, longueur: longueur }
		end

		#*********************************Chapeau de gendarme*************************************

		def self.profil_chapeau_double(largeur, hauteur,offset, lame_group,epaisseur_lames, resolution = 40, ratio_centre = 0.4)
			lames = lame_group.entities.grep(Sketchup::Group) 
			position = [] 
			nb_lame_cutter_par_lame_lambris = resolution/lames.length
			lames.each do |lame|
				position_min = (lame.bounds.min.x-offset.x) #1mm= espace entre 2 lames de lambris/2 pour être dans l'axe
				position_max = (lame.bounds.max.x-offset.x)
				largeur_lame_cutter = (position_max - position_min)/nb_lame_cutter_par_lame_lambris
				(0..nb_lame_cutter_par_lame_lambris-1).each do |i|
					position << (position_min + i * largeur_lame_cutter) 
				end	
			end
			h = hauteur.to_f
			w = largeur.to_f
			wc = w * ratio_centre
			wl = (w - wc) / 2.0
			diag=Math.sqrt((w/2.0)**2+h**2)
			alpha=Math.atan(h/(w/2.0))
			a=(diag*((1-ratio_centre)/2.0))
			# Centres latéraux EXTERIEURS et VERS LE HAUT
			cx_left  = 0 
			cx_right = w
			#  Rayon des arcs latéraux ---
			rl = a* (Math.tan(Math::PI/2-alpha))
			cz_lat   = Math.sqrt(rl**2+a**2) - 25.mm    # <<< centre au-dessus - 25.mm ?
			#  Arc central convexe ---
			b=(diag-2*a)/2
			rc=b * Math.tan(Math::PI/2-alpha)
			cx_mid = w / 2.0 
			cz_mid = -(rc - h) 
			pts = []
			resolution.times do |i|
				t = i.to_f / (resolution )   #- 1
				x = position[i]
				if (i <= (3 * nb_lame_cutter_par_lame_lambris))   #x <= x1
					# --- Arc concave gauche ---
					z = cz_lat - Math.sqrt(rl**2 - (x - cx_left)**2)
				elsif i <= (7 * nb_lame_cutter_par_lame_lambris)   #x <= x2
					# --- Arc convexe central ---
					z = cz_mid + Math.sqrt(rc**2 - (x  - cx_mid)**2)
				else
					# --- Arc concave droit ---
					z = cz_lat - Math.sqrt(rl**2 - (x  - cx_right)**2)
				end
				pts << Geom::Point3d.new(x, offset.y, z - 1.mm)			# -1.mm
				pts << Geom::Point3d.new(x, offset.y + epaisseur_lames, z - 1.mm)	
			end
			pts << Geom::Point3d.new(w, offset.y, pts[0].z)
			pts << Geom::Point3d.new(w, offset.y + epaisseur_lames, pts[1].z)
			pts
		end

		def self.coupe_chapeau_double(lambris_group, largeur, hauteur, offset,nb_lame,nb_lamelle_par_lame,pts_profil_lambris_world,epaisseur_lames,espace, resolution,material_name,normal: :yminus)
			ratio_centre = 0.4
			#*******points des N lamelles rectangulaires*******
			points_toutes_lamelles =  profil_chapeau_double(largeur, hauteur,offset,lambris_group,epaisseur_lames, resolution,ratio_centre)
			points_lamelles_contour_lambris_horizontal,points_lamelles,cutter_group=coupe_lambris_sur_points_test_chapeau(lambris_group,points_toutes_lamelles,nb_lamelle_par_lame,pts_profil_lambris_world,epaisseur_lames,espace,offset,normal: normal)
			# projection des N profils lamelles
			lames = lambris_group.entities.grep(Sketchup::Group) 
			(0...lames.length).each do |i|
				(0...4).each do |j|
					horizontal_profile = points_lamelles_contour_lambris_horizontal[i][j]
					inclined_face      = points_lamelles[i][j]
					#Projection
					projected_profile = UtilsAuvent.project_horizontal_profile_on_inclined_face(
						horizontal_profile,
						inclined_face
					)
					face = lambris_group.entities.add_face(projected_profile)
					mat = @materials[material_name]
					lames = lambris_group.entities.grep(Sketchup::Group)
					lames.each do |lame|
						reappliquer_materiau(lame,mat)
					end	
					reappliquer_materiau(lambris_group,mat)
				end    #lamelles
			end   #lames
		end  
		  
		 def self.coupe_solide_chapeau(target_group, cutter_group)
			ents = target_group.entities
			tr_target  = target_group.transformation
			tr_cutter  = cutter_group.transformation
			# Récupérer la face du cutter ---
			cutter_face = cutter_group.entities.grep(Sketchup::Face).first
			return unless cutter_face
			# Définir le plan de coupe ---
			plane_point  = cutter_face.vertices.first.position.transform(tr_cutter)
			plane_normal = cutter_face.normal.transform(tr_cutter)
			plane_normal.normalize!
			#  Intersection ---
			ents.intersect_with(true, IDENTITY, ents, IDENTITY, true, cutter_group)
			# Supprimer les faces du mauvais côté ---
			faces_to_delete = []
			ents.grep(Sketchup::Face).each do |f|
				p_local  = f.vertices.first.position
				p_global = p_local.transform(tr_target)
				if UtilsAuvent.point_side(p_global, plane_point, plane_normal) > 0
					faces_to_delete << f
				end
			end
			faces_to_delete.each(&:erase!)
			# Supprimer les arêtes du mauvais côté ---
			edges_to_delete = []
			ents.grep(Sketchup::Edge).each do |e|
				if e.faces.empty?
					edges_to_delete << e
				else
					p_local  = e.start.position
					p_global = p_local.transform(tr_target)
					if UtilsAuvent.point_side(p_global, plane_point, plane_normal) > 0
					edges_to_delete << e
					end
				end
			end
			edges_to_delete.each do |e|
				next unless e.valid? && !e.deleted?
				begin
					e.erase!
				rescue TypeError
					puts " L’edge était déjà supprimé → on ignore"
				rescue
					puts "Toute autre erreur → on ignore aussi"
				end
			end
			#  Nettoyage vertices ---
			ents.grep(Sketchup::Vertex).each do |v|
				v.erase! if v.edges.empty?
			end
		end
		 
		def self.coupe_solide_clins_geometrie(target_group, cutter_group)
			ents = target_group.entities
			tr_target  = target_group.transformation
			tr_cutter  = cutter_group.transformation
			#  Face du cutter ---
			cutter_face = cutter_group.entities.grep(Sketchup::Face).first
			return unless cutter_face
			plane_point  = cutter_face.vertices.first.position.transform(tr_cutter)
			plane_normal = cutter_face.normal.transform(tr_cutter)
			plane_normal.normalize!
			# Intersection ---
			ents.intersect_with(true, IDENTITY, ents, IDENTITY, true, cutter_group)
			edges=  ents.grep(Sketchup::Edge)
			zmax = edges.map { |e| [e.start.position.z, e.end.position.z] }.flatten.max
			origin = cutter_group.transformation.origin 
			normal = cutter_group.transformation.zaxis
			plane = {point: origin,normal: normal }
			sorted = GeometryFilter.sort_edges(edges, plane)
			sorted[:above]   # edges au-dessus
			sorted[:below]   # edges en-dessous
			sorted[:on]      # edges sur le plan
			sorted[:cross]   # edges traversants
			above=sorted[:above]
			below=sorted[:below]
			on=sorted[:on]
			cross=sorted[:cross]
			above.each do |e|
				next unless e.valid? && !e.deleted?	
				if((e.start.position.z-zmax).abs < 1.mm || (e.end.position.z-zmax).abs < 1.mm)
					e.erase!
				end
			end
			# Nettoyage final ---
			ents.grep(Sketchup::Face).each { |f| f.erase! if f.vertices.empty? }
			ents.grep(Sketchup::Edge).each { |e| e.erase! if e.faces.empty? }
			ents.grep(Sketchup::Vertex).each { |v| v.erase! if v.edges.empty? }
		end

		def self.coupe_lambris_sur_points_test_chapeau(lame_group, pts,nb_lamelle_par_lame,pts_profil_lambris_world,epaisseur_lames,espace,offset,normal: :zminus)
			cutter_group = []
			#creation de face pour chaque element
			lames = lame_group.entities.grep(Sketchup::Group) 
			indice=0
			indice_lame=0
			indice_lamelle=0
			indice_grp=0	
			points_lamelles = Array.new(lames.length) { [] }
			points_lamelles_contour_lambris_horizontal = Array.new(lames.length) { [] }
			lames.each do |lame_lambris|
				cutter_group, points_lamelles[indice_lame]  = UtilsAuvent.create_cutter(pts,indice_lame,indice_lamelle,offset,lame_lambris,nb_lamelle_par_lame,epaisseur_lames,espace,normal: :zminus)
				pts_lambris_courant = [ 
					pts_profil_lambris_world[indice_lame][0],
					pts_profil_lambris_world[indice_lame][1],		  
					pts_profil_lambris_world[indice_lame][2],		  
					pts_profil_lambris_world[indice_lame][3],		  		  
					pts_profil_lambris_world[indice_lame][4],
					pts_profil_lambris_world[indice_lame][5],		  
					pts_profil_lambris_world[indice_lame][6],		  
					pts_profil_lambris_world[indice_lame][7]
				]
				points_lamelles_contour_lambris_horizontal[indice_lame] = genere_profils_lamelles(pts_lambris_courant,nb_lamelle_par_lame,true)
				coupe_solide_clins_geometrie(lame_lambris, cutter_group)
				indice_lamelle+=nb_lamelle_par_lame * 2
				indice_lame+=1
				cutter_group.erase!
			end
			return points_lamelles_contour_lambris_horizontal, points_lamelles,cutter_group
		end

		#*********************************Inventaire matériel**************************************

		def self.generate_liste_matériel(gents)
			liste = []
			liste = scan_entities(gents,liste)        #gents=auvent_def.entities
			liste.each do |p|
				puts("#{p}")
			end
		end

		def self.get_material(name)
			model = Sketchup.active_model
			mats  = model.materials
			# Déjà dans le modèle ?
			mat = mats[name]
			return mat if mat
			mat = Sketchup.active_model.materials[name]  #c'est pareil que précédent
			return mat if mat
			# Dans la bibliothèque système ?
			lib_path = Sketchup.find_support_file("#{name}.skm", "Materials")
			return mats.load(lib_path) if lib_path
			# Dans un sous-dossier
			lib_path = Sketchup.find_support_file("#{name}.skm", "Materials/Textures")
			return mats.load(lib_path) if lib_path
			# Échec
			UI.messagebox("Matériau introuvable : #{name}")
			nil
		end

		def self.scan_entities(entities, liste)
			entities.each do |child|
				# On ne descend que dans Group ou ComponentInstance
				if child.is_a?(Sketchup::Group) || child.is_a?(Sketchup::ComponentInstance)
					nom = child.name.to_s.strip.upcase
					if ["CHEVRON", "LITEAU", "PANNE", "POTEAU", "XY","CLIN","LAME","LAMBRIS",
						"CUTTER","PANNEAU CLINS","PANNEAU LAMBRIS","RIVE","GOUTIERE","SOL",
						"ANGLE_XZ","ANGLE_YZ","COUVERTURE"].include?(nom)
						bb = child.bounds
						dims = [
							(bb.max.x - bb.min.x).abs.to_cm,
							(bb.max.y - bb.min.y).abs.to_cm,
							(bb.max.z - bb.min.z).abs.to_cm
						].sort  
						liste << {
							type: nom,
							longueur: dims[2].round(1),
							largeur:  dims[1].round(1),
							épaisseur:  dims[0].round(1)   #,
							#guid: child.persistent_id
						}
					end
					# DESCENTE RÉCURSIVE SÉCURISÉE
					if child.is_a?(Sketchup::ComponentInstance)
						scan_entities(child.definition.entities, liste)
					elsif child.is_a?(Sketchup::Group)
						scan_entities(child.entities, liste)
					end
				end # if Group/ComponentInstance
			end # each
			liste
		end
		#***********************************************************************
	 end #module  FctAuvent
	 
	 # encoding: UTF-8
	module GeometryFilter
		TOL = 0.001.mm
		# ---------------------------------------------------------------------------
		# Plane structure : { point: Geom::Point3d, normal: Geom::Vector3d }
		# ---------------------------------------------------------------------------
		# Distance signée d’un point au plan
		def self.signed_distance(p, plane)
			(p - plane[:point]).dot(plane[:normal])
		end

		# Projection d’un point sur le plan
		def self.project_point(p, plane)
			v = p - plane[:point]
			d = v.dot(plane[:normal])
			p - plane[:normal] * d
		end

		# Edge traverse le plan (extrémités de signes opposés)
		def self.edge_crosses_plane?(edge, plane)
			d1 = signed_distance(edge.start.position, plane)
			d2 = signed_distance(edge.end.position, plane)
			(d1 > TOL && d2 < -TOL) || (d1 < -TOL && d2 > TOL)
		end

		# Classement d’un edge : :above, :below, :on, :cross
		def self.classify_edge(edge, plane)
			d1 = signed_distance(edge.start.position, plane)
			d2 = signed_distance(edge.end.position, plane)

			# Cas traversant
			return :cross if edge_crosses_plane?(edge, plane)

			# Cas "sur le plan"
			if d1.abs < TOL && d2.abs < TOL
				return :on
			end

			# Cas au-dessus
			if d1 > TOL && d2 > TOL
				return :above
			end

			# Cas en-dessous
			if d1 < -TOL && d2 < -TOL
				return :below
			end

			# Cas mixte mais non traversant (edge incliné tangent)
			return :cross
		end

		# Tri complet des edges
		def self.sort_edges(edges, plane)
			result = {
				above: [],
				below: [],
				on: [],
				cross: []
			}

			edges.each do |e|
				cat = classify_edge(e, plane)
				result[cat] << e
			end

		result
	  end

		def self.face_centroid(face)
			pts = face.vertices.map(&:position)
			Geom::Point3d.new(
				pts.map(&:x).sum / pts.length,
				pts.map(&:y).sum / pts.length,
				pts.map(&:z).sum / pts.length
			)
		end

		def self.classify_face(face, plane)
			c = face_centroid(face)
			d = signed_distance(c, plane)

			return :on if d.abs < TOL
			return :above if d > TOL
			return :below if d < -TOL
	  end

		def self.sort_faces(faces, plane)
			result = { above: [], below: [], on: [] }
			faces.each do |f|
				cat = classify_face(f, plane)
				result[cat] << f
			end
		result
		end
	end   #module GeometryFilter
 end  #module Auvent
