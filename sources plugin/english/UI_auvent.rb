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
#AUVENT_SUD (ComponentDefinition)---------------------------->derived from the name of the descriptive file
#  └── Ossature Auto (Group)
#        ├── POST (Group)
#        ├── RAFTER (Group)
#        ├── BATTEN (Group)
#        ├── GUTTER (Group)
#        ├── FASCIA (Group)
#        |...
#        └── ROOFING(Group)

module Auvent
  module UIAuvent
  #SECTION 1 — UI menu principal
    unless file_loaded?(__FILE__)
      UI.menu("Plugins").add_item("Generate framing from file") {
        begin
          model = Sketchup.active_model
          model.layers.each { |layer| layer.visible = true }
          path = UI.openpanel("Select the framing file", "", "Texte|*.txt||")
          next unless path
          # --- Component name generation ---
          filename  = File.basename(path, ".*")
          comp_name = filename.upcase.gsub(/\s+/, "_")
          # We store the component's name in memory.
          FctAuvent.last_component_name = comp_name
          FctAuvent.generer_ossature_depuis_fichier(path, comp_name)
          # model = Sketchup.active_model
          view = model.active_view
          view.refresh
          #Sketchup.send_action("viewTop:")
          UI.start_timer(0.1, false) {
            Sketchup.send_action("viewIso:")
          }
          view.zoom_extents
          view.refresh
        rescue => e
          UI.messagebox("#{e.class}: #{e.message}\n\n#{e.backtrace.join("\n")}")
          raise e
        end
      }

      UI.menu("Plugins").add_item("Generate roof covering") {
        begin
          root=get_root_auvent()
          if(root!=nil)
            prompts  = ["Cover type"]
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
      
      UI.menu("Plugins").add_item("Generate A4 drawing (3 or 4 views)") {
        begin
          comp_name = FctAuvent.last_component_name
          if comp_name.nil?
            UI.messagebox("No canopy generated. Generate the framework first.")
            next
          end
          model = Sketchup.active_model
          auvent_inst = model.active_entities.grep(Sketchup::ComponentInstance)
          .find { |i| i.definition.name == comp_name }
          unless auvent_inst
            UI.messagebox("Unable to find the awning. '#{comp_name}' in the model.")
            return
          end
          # The component's entities
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

      UI.menu("Plugins").add_item("Export A4 plan (JPG)") {
        begin
          FctAuvent.export_plan_a4_optimise 
        rescue => e
          UI.messagebox("#{e.class}: #{e.message}\n\n#{e.backtrace.join("\n")}")
          raise e
        end
      }

      UI.menu("Plugins").add_item("Generate roof for garage") {
        begin
          model = Sketchup.active_model
          sel = model.selection
          if sel.empty? || !sel.first.is_a?(Sketchup::Group)
            UI.messagebox("First, select the garage group.")
            next
          end
          garage = sel.first
          gents = garage.entities
          prompts  = ["Cover type"]
          defaults = [COVER_TYPES.values.first[:name]]
          list     = [COVER_TYPES.values.map { |t| t[:name] }.join("|")]
          result = UI.inputbox(prompts, defaults, list)
          next unless result
          FctAuvent.generate_couverture(result[0], garage,garage,0)             #Slope 1   East
          FctAuvent.generate_couverture(result[0], garage,garage,1)             #Slope 2   West
          FctAuvent.delete_liteaux(gents)
        rescue => e
          UI.messagebox("#{e.class}: #{e.message}\n\n#{e.backtrace.join("\n")}")
          raise e
        end
      }

      UI.menu("Plugins").add_item("Export the hardware inventory from the console") {
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
      menu = UI.menu("Plugins").add_submenu("Utilities")
      menu.add_item("Select a edge") {
        Sketchup.send_action("showRubyPanel:")
        UtilsAuvent.select_vertex
      }
      menu.add_item("Display the hierarchy in the console") {
        Sketchup.send_action("showRubyPanel:")
        Hierarchy.printHierarchy
      }
      
    file_loaded(__FILE__)
    end   #unless file_loaded

    def self.get_root_auvent()
        comp_name = FctAuvent.last_component_name
        if comp_name.nil?
          UI.messagebox("No canopy generated. Generate the framework first.")
          return nil
        end
        model = Sketchup.active_model
        auvent_def = model.definitions[comp_name]
        if auvent_def.nil?
          UI.messagebox("The component '#{comp_name}' no longer exists in the model.")
          return nil
        end
        root = UtilsAuvent.get_ossature_group(auvent_def)
        return unless root
        root
    end
    
  end   #module UIAuvent
end    #module Auvent