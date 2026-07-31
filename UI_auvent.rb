# Written by Marc Prieur (marco40_github@sfr.fr)
#                                    UI_auvent.rb 
#                               project plugin-squetchup-ruby
#                                 Plugin for Squetchup
# **************************************************************************************
# Creative Commons Attrib Share-Alike License
# You are free to use/extend this library but please abide with the CC-BY-SA license:
# Attribution-NonCommercial-ShareAlike 4.0 International License
# http://creativecommons.org/licenses/by-nc-sa/4.0/

# All text above must be included in any redistribution.
#  **********************************************************************************

require_relative "auvent/auvent_constants"
require_relative "auvent/utils_auvent"
require_relative "auvent/auvent"
require_relative "auvent/PrintHierarchy"
#download squetchup 2017:https://web.archive.org/web/20220217222923/https://download.sketchup.com/sketchupmake-2017-2-2555-90782-en-x64.exe
#arborescence
#AUVENT_SUD (ComponentDefinition)---------------------------->déduit du nom du fichier descriptif
#  └── Ossature Auto (Group)
#        ├── POTEAU (Group)
#        ├── CHEVRON (Group)
#        ├── LITEAU (Group)
#        ├── GOUTIERE (Group?)
#        ├── RIVE (Group?)
#        |
#        └── COUVERTURE(Group)

#Objet					Type					Ce qu’il contient
#auvent_def				ComponentDefinition		La définition AUVENT_SUD
#auvent_def.entities	Entities				Les entités internes du composant
#root					Group					Le groupe “Ossature Auto” créé dans la définition

module Auvent
 module UIAuvent
#SECTION 1 — UI menu principal
  unless file_loaded?(__FILE__)
	UI.menu("Plugins").add_item("Générer ossature depuis fichier") {
		begin	
			model = Sketchup.active_model
			model.layers.each { |layer| layer.visible = true }
			path = UI.openpanel("Choisir le fichier ossature", "", "Texte|*.txt||")
			next unless path
			# --- Génération du nom de composant ---
			filename  = File.basename(path, ".*") 
			comp_name = filename.upcase.gsub(/\s+/, "_")
			# On mémorise le nom du composant
			FctAuvent.last_component_name = comp_name
			FctAuvent.generer_ossature_depuis_fichier(path, comp_name)
			
			
			# model = Sketchup.active_model	
			view = model.active_view
			view.refresh
			Sketchup.send_action("viewTop:")
			Sketchup.send_action("viewIso:")
			view.zoom_extents
			view.refresh  
		rescue => e
			UI.messagebox("#{e.class}: #{e.message}\n\n#{e.backtrace.join("\n")}")
			raise e
		end
	}

    UI.menu("Plugins").add_item("Générer couverture") {
		begin		
			root=get_root_auvent()
			if(root!=nil)
				prompts  = ["Type de couverture"]
				defaults = [COVER_TYPES.values.first[:name]]
				list     = [COVER_TYPES.values.map { |t| t[:name] }.join("|")]
				result = UI.inputbox(prompts, defaults, list)
				next unless result
				FctAuvent.generate_couverture(result[0], root)
			end
		rescue => e
			UI.messagebox("#{e.class}: #{e.message}\n\n#{e.backtrace.join("\n")}")
			raise e
		end
	}
	
	UI.menu("Plugins").add_item("Générer plan A4 (3 ou 4 vues)") {
		begin		
			comp_name = FctAuvent.last_component_name
			if comp_name.nil?
				UI.messagebox("Aucun auvent généré. Lance d'abord la génération de l'ossature.")
				next
			end
			model = Sketchup.active_model
			auvent_inst = model.active_entities.grep(Sketchup::ComponentInstance)
			.find { |i| i.definition.name == comp_name }
			unless auvent_inst
				UI.messagebox("Impossible de trouver l'auvent '#{comp_name}' dans le modèle.")
				return
			end
			# Les entités du composant
			main = auvent_inst
			
			if(comp_name=="AUVENT_GARAGE")
				gauche,face,dessus,droite= FctAuvent.generate_2d_views_from(main)
			else
				gauche,face,dessus= FctAuvent.generate_2d_views_from(main)
			end
			FctAuvent.generate_plan_a4_layout(face, gauche, dessus, droite)		
		rescue => e
			UI.messagebox("#{e.class}: #{e.message}\n\n#{e.backtrace.join("\n")}")
			raise e
		end		
	}

	UI.menu("Plugins").add_item("Exporter plan A4 (JPG)") {
		begin
			FctAuvent.export_plan_a4_optimise   #--->trop clair
		rescue => e
			UI.messagebox("#{e.class}: #{e.message}\n\n#{e.backtrace.join("\n")}")
			raise e
		end
	}

	UI.menu("Plugins").add_item("Générer toiture sur garage") {
		begin
			model = Sketchup.active_model
			sel = model.selection
			if sel.empty? || !sel.first.is_a?(Sketchup::Group)
			  UI.messagebox("Sélectionne d'abord le groupe du garage.")
			  next
			end
			garage = sel.first
			gents = garage.entities
			prompts  = ["Type de couverture"]
			defaults = [COVER_TYPES.values.first[:name]]
			list     = [COVER_TYPES.values.map { |t| t[:name] }.join("|")]
			result = UI.inputbox(prompts, defaults, list)
			next unless result
			FctAuvent.generate_couverture(result[0], garage,garage,0)             #pente 1   Est
			FctAuvent.generate_couverture(result[0], garage,garage,1)             #pente 2  Ouest pb panneaux ?
			FctAuvent.delete_liteaux(gents)
		rescue => e
			UI.messagebox("#{e.class}: #{e.message}\n\n#{e.backtrace.join("\n")}")
			raise e
		end
	}

	UI.menu("Plugins").add_item("Exporter l'inventaire du matériel sur la console") {
		begin		
			root=get_root_auvent()
			if(root!=nil)
				FctAuvent.generate_liste_matériel(root.entities)
			end
		rescue => e
			UI.messagebox("#{e.class}: #{e.message}\n\n#{e.backtrace.join("\n")}")
			raise e
		end
	}

#SECTION 2 — UI utilitaires
	
    menu = UI.menu("Plugins").add_submenu("Utilitaires")
	
	menu.add_item("Sélectionner une ligne") {
		Sketchup.send_action("showRubyPanel:")
		UtilsAuvent.select_vertex
	}
	menu.add_item("Afficher la Hierarchie dans la console") {
		Sketchup.send_action("showRubyPanel:")	
		Hierarchy.printHierarchy 
	}
	
	file_loaded(__FILE__)
  end   #unless file_loaded

  def self.get_root_auvent()
  			comp_name = FctAuvent.last_component_name
			if comp_name.nil?
				UI.messagebox("Aucun auvent généré. Lance d'abord la génération de l'ossature.")
				return nil
			end
			model = Sketchup.active_model
			auvent_def = model.definitions[comp_name]
			if auvent_def.nil?
				UI.messagebox("Le composant '#{comp_name}' n'existe plus dans le modèle.")
				return nil
			end
			root = UtilsAuvent.get_ossature_group(auvent_def)
			return unless root
			root
  
  end
 end   #module UIAuvent
end    #module Auvent