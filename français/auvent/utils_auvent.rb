# Written by Marc Prieur (marco40_github@sfr.fr)
#                                    utils_auvent.rb 
#                               project plugin-squetchup-ruby
#                                 Plugin for Squetchup
# **************************************************************************************
# Creative Commons Attrib Share-Alike License
# You are free to use/extend this library but please abide with the CC-BY-SA license:
# Attribution-NonCommercial-ShareAlike 4.0 International License
# http://creativecommons.org/licenses/by-nc-sa/4.0/

# All text above must be included in any redistribution.
#  **********************************************************************************

module Auvent
  module UtilsAuvent

#***********************************************************************************************
    def self.apply_style()
      model = Sketchup.active_model
      ro = model.rendering_options
      # Mode filaire / traits uniquement
      ro["EdgeDisplayMode"] = 1      # 0 = Wireframe, 1 = HiddenLine, 2 = Shaded, etc.
      # Couleur des traits : noir
      ro["EdgeColorMode"]   = 0      # 0 = All same, 1 = By material
      ro["ForegroundColor"] = Sketchup::Color.new(0, 0, 0)
      # Profils / épaisseur apparente
      ro["ProfileEdges"]  = true     # Active les profils
      ro["ProfilesWidth"] = 2        # Épaisseur des profils (1,2,3…)
      # Nettoyage visuel
      ro["DisplayShadows"]      = false
      ro["DisplayColorByLayer"] = false
      ro["DisplaySketchAxes"]   = false
      ro["DisplaySky"]          = false
      ro["DisplayGround"]       = false
      ro["LineEndEdges"] = false
      ro["LineExtension"] = false
      ro["BackgroundColor"] = Sketchup::Color.new(255,255,255)
      ro["UseBackgroundColor"] = true
      model.active_view.refresh
     end

    def self.find_group_by_id(root, id)
      root.each do |e|
        if e.is_a?(Sketchup::Group) && e.entityID == id
          return e
        end
        if e.respond_to?(:entities)
          found = find_group_by_id(e.entities, id)
          return found if found
        end
      end
      nil
    end

    def self.get_ossature_group(definition)
      definition.entities.grep(Sketchup::Group).find { |g| g.name == "Ossature Auto" }
    end

    AUVENT_NAMES = ["Ossature Auto", "AUVENT", "Auvent", "ossature", "Ossature"]
    def self.find_auvent_group
      model = Sketchup.active_model
      group = model.entities.grep(Sketchup::Group).find { |g| AUVENT_NAMES.include?(g.name) }
      return group if group
      model.entities.grep(Sketchup::Group).each do |g|
        sub = g.entities.grep(Sketchup::Group).find { |sg| AUVENT_NAMES.include?(sg.name) }
        return sub if sub
      end
      nil
    end

#***********************************************************************************************

    def self.extruder_structure
      model = Sketchup.active_model
      ents  = model.active_entities
      group = ents.grep(Sketchup::Group).last
      gents = group.entities
      gents.grep(Sketchup::Edge).each do |edge|
        name = edge.get_attribute("SU_DefinitionSet", "name") rescue nil
        next unless name
        type =
          if name.include?("Poteau")  then :poteau
          elsif name.include?("Poutre") then :poutre
          elsif name.include?("Chevron") then :chevron
          elsif name.include?("Liteau") then :liteau
          end
        next unless type
        p = PARAMS[type]
        extrude_piece(gents, edge, p[:section], p[:offset_z], p[:rotation])
      end
    end

    def self.point_side(p, plane_point, plane_normal)
      (p - plane_point).dot(plane_normal)
    end

    def self.create_cutter(points_toutes_lamelles,indice_lame,indice_lamelles,offset,lame,nb_lamelle_par_lame,epaisseur_lames,espace,normal: :zminus)
      points_lamelles = Array.new(nb_lamelle_par_lame) { [] }
      cutter_group = lame.entities.add_group
      cutter_group.name = "CUTTER_LOCAL_PTS"
      tr = Geom::Transformation.translation(offset)
      cutter_group.transform!(tr)
      cutter_face = []
      indice_lamelle=0
      (0...(nb_lamelle_par_lame*2)-1).step(2) do |i|
        p1 = points_toutes_lamelles[i+indice_lamelles]
        p2 = points_toutes_lamelles[i+1+indice_lamelles]
        p3 =points_toutes_lamelles[i+3+indice_lamelles]
        p4 =points_toutes_lamelles[i+2+indice_lamelles]
        points = [p1, p2, p3, p4]
        points.map! { |pt| pt.transform(tr) }
        points_lamelles[indice_lamelle] << points[0]
        points_lamelles[indice_lamelle] << points[1]
        points_lamelles[indice_lamelle] << points[2]
        points_lamelles[indice_lamelle] << points[3]
        cutter_face[indice_lamelle] = cutter_group.entities.add_face([p1,p2,p3,p4])
        indice_lamelle += 1
      end
      return cutter_group , points_lamelles
    end

    #Regarding the panels, in some cases there was a problem with the polycarbonate.
    #pour les panneaux dans certain cas il y avait un problème avec le polycarbonate 
    def self.apply_material_stable(gents, mat)
      gents.grep(Sketchup::Face).each { |f| f.material = mat }
      faces = gents.grep(Sketchup::Face)
      faces.each do |f|
        f.material = mat
        f.back_material = mat
      end
      # Forced refresh/Rafraîchissement forcé
      UI.start_timer(1, false) {
        Sketchup.active_model.active_view.invalidate
      }
    end

#**************************************edges*********************************************************
    def self.edge_with_lowest_y(edges)
      edges.min_by do |e|
        y1 = e.start.position.y
        y2 = e.end.position.y
        [y1, y2].min
      end
    end
    
    def self.edge_with_highest_y(edges)
      edges.max_by do |e|
        y1 = e.start.position.y
        y2 = e.end.position.y
        [y1, y2].max
      end
    end

    def self.edges_with_highest_y(edges)
      max_y = edges.map { |e| [e.start.position.y, e.end.position.y].max }.max
      edges.select do |e|
        [e.start.position.y, e.end.position.y].max == max_y
      end
    end

    def self.edges_with_lowest_y(edges)
      min_y = edges.map { |e| [e.start.position.y, e.end.position.y].min }.min
      edges.select do |e|
        [e.start.position.y, e.end.position.y].min == min_y
      end
    end

    def self.edges_with_highest_x(edges)
      max_x = edges.map { |e| [e.start.position.x, e.end.position.x].max }.max
      edges.select do |e|
        [e.start.position.x, e.end.position.x].max == max_x
      end
    end

    def self.edges_with_lowest_x(edges)
      min_x = edges.map { |e| [e.start.position.x, e.end.position.x].min }.min
      edges.select do |e|
        [e.start.position.x, e.end.position.x].min == min_x
      end
    end

    def self.edges_with_highest_z(edges)
      max_z = edges.map { |e| [e.start.position.z, e.end.position.z].max }.max
      edges.select do |e|
        [e.start.position.z, e.end.position.z].max == max_z
      end
    end

    def self.edge_with_highest_z(edges)
      edges.max_by do |e|
        z1 = e.start.position.z
        z2 = e.end.position.z
        [z1, z2].max
      end
    end
    
    def self.long_edge_of(group)
      edges = group.entities.grep(Sketchup::Edge)
      edges.max_by { |e| e.length }
    end

    def self.long_edges_of(edges)
      max_len = edges.map(&:length).max
      edges.select { |e| e.length == max_len }
    end

    def self.short_edge_of(group)
      edges = group.entities.grep(Sketchup::Edge)
      edges.min_by { |e| e.length }
    end

    def self.collect_edges_with_transform(group, tr_parent = Geom::Transformation.new)
      edges = []
      tr = tr_parent * safe_transformation(group)
      group.entities.each do |e|
        if e.is_a?(Sketchup::Face)
          e.outer_loop.edges.each do |edge|
            p1 = edge.start.position.transform(tr)
            p2 = edge.end.position.transform(tr)
            edges << [p1, p2]
          end
        elsif e.is_a?(Sketchup::Group)
          edges.concat(collect_edges_with_transform(e, tr))
        end
      end
      edges
    end

#**************************************vertex*********************************************************

    def self.select_vertex
      sel = Sketchup.active_model.selection
      if sel[0].is_a?(Sketchup::Edge)
        puts_vertex(sel[0],"test")
      else
        puts "Select an edge first./Sélectionne d'abord une arête."
      end
    end

#************************************faces***********************************************************

    def self.global_transformation_for_face(face)
      owner_id = face.get_attribute("auvent", "owner_group_id")
      return Geom::Transformation.new unless owner_id
      group = find_group_by_id(Sketchup.active_model.entities, owner_id)
      return Geom::Transformation.new unless group
      arr = group.get_attribute("auvent", "tr")
      return Geom::Transformation.new unless arr
      Geom::Transformation.new(arr)
    end

    def self.add_face_to_definition(definition, pts,lignes_arrieres=0)
      ents = definition.entities
      pts = pts.uniq
      return if pts.length < 3
      begin
        face = ents.add_face(pts)
        face.reverse! if face.normal.z < 0
      rescue
        (0...pts.length).each do |i|
          edge=ents.add_line(pts[i], pts[(i+1) % pts.length])
        end
      end
    end

    def self.collect_all_faces(entity)
      faces = []
      if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        ents = entity.is_a?(Sketchup::Group) ? entity.entities : entity.definition.entities
        ents.each do |e|
          if e.is_a?(Sketchup::Face)
            faces << e
          elsif e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
            faces.concat(collect_all_faces(e))
          end
        end
      end
      faces
    end

    def self.create_face_oriented(ents, contour, axis: :x, positive: true)
      face = ents.add_face(contour)
      return nil unless face
      target =
        case axis
        when :x then Geom::Vector3d.new(1, 0, 0)
        when :y then Geom::Vector3d.new(0, 1, 0)
        when :z then Geom::Vector3d.new(0, 0, 1)
        else
        raise ArgumentError, "axis must be :x, :y or :z"
        end
      target.reverse! unless positive
      if face.normal.dot(target) < 0
        face.reverse!
      end
      face
    end

    def self.project_horizontal_profile_on_inclined_face(points_horizontal, points_inclined)
      plane = Geom.fit_plane_to_points(points_inclined)
      a, b, c, d = plane
      projected = points_horizontal.map do |pt|
        x = pt.x
        y = pt.y
        z = (-d - a * x - b * y) / c
        Geom::Point3d.new(x, y, z)
      end
      projected
    end

    def self.plus_grande_face(group)
      faces = group
      return nil if faces.empty?
      faces.max_by { |f| f.area }
    end

    def self.plus_grande_face_world(group)
      tr = group.transformation
      faces = group.entities.grep(Sketchup::Face)
      return nil if faces.empty?
      faces.max_by do |f|
        f.area * tr.scaling
      end
    end

    def self.face_du_dessous_world(chevron_group)
      faces = chevron_group.entities.grep(Sketchup::Face)
      tr = chevron_group.transformation
      faces_down = faces.select do |f|
        world_normal = f.normal.transform(tr)
        world_normal.dot(Z_AXIS) < 0
      end
      return nil if faces_down.empty?
      faces_down.min_by do |f|
        world_normal = f.normal.transform(tr)
        world_normal.dot(Z_AXIS)
      end
    end

    def self.face_du_dessous(chevron_group)
      faces = chevron_group.entities.grep(Sketchup::Face)
      inclined = faces.select { |f|
        nz = f.normal.z
        nz.abs > 0.01 && nz.abs < 0.99
      }
      return nil if inclined.empty?
      faces_down=plus_grande_face(inclined)
      end

#**************************************divers puts*********************************************************

    def self.eval_expr(expr, vars)
      return expr if expr.is_a?(Numeric)
	  # Replace the variables with their values
      # Remplacer les variables par leurs valeurs
      vars.each { |k, v| expr = expr.gsub(/\b#{k}\b/, v.to_s) }
      # Convert degrees "15°" to radians
	  # Convertir les degrés "15°" en radians
      expr = expr.gsub(/(\d+)\s*°/) { ($1.to_f * Math::PI / 180.0).to_s }
      begin
        return eval(expr)
      rescue
        #UI.messagebox("Error in the expression / Erreur dans l'expression : #{expr}")
        return 0
      end
    end

    def self.safe_transformation(g)
      return nil unless g.valid? && !g.deleted?
      g.transformation.clone
    end

    #Converts a text value in millimeters into a clean Ruby Float.
    # Convertit une valeur texte en millimètres vers un Float Ruby propre
      # Accepted examples / Exemples acceptés :
      # "60", "60mm", "60,0", "60,0mm", "-45,25 mm"
    def self.parse_mm(value)
      return 0.0 if value.nil?
      str = value.to_s.strip
      str = str.gsub(',', '.')
      # Removes everything except digits, a decimal point, and a minus sign -
      # Supprime tout sauf chiffres, point, signe -
      str = str.gsub(/[^\d\.\-]/, '')
      str.to_f
      end

    def self.dbg_length(label, value)
      puts "class: #{label} : #{value} #{value.class}, (pouces=#{value.to_f}, mm=#{value.to_mm})"
    end

    def self.longueur_mm(edge)# Conversion pouces internes → millimètres réels
      edge.length.to_f * 25.4
    end

    def self.puts_vertex(edge,text)
      if edge.is_a?(Sketchup::Edge)
        v1 = edge.start.position
        v2 = edge.end.position
        puts "#{text }Extrémité 1 : #{v1}"
        puts "#{text }Extrémité 2 : #{v2}"
        len = v1.distance(v2)
        puts "len : #{len}"
      else
        if(edge.class==Sketchup::Group)
          puts_all_edges_from_group(edge)
        else
          puts "puts_vertex pas un edge: #{edge.class}}"
        end
      end
    end
    
    def self.puts_all_edges(edges)
      edges.each_with_index do |e, i|
        puts_vertex(e, "Edge #{i}")
      end
    end

    def self.puts_all_edges_from_group(group)
      edges = group.entities.grep(Sketchup::Edge)
      puts "---- EDGES OF #{group.name} ----"
      edges.each_with_index do |e, i|
        puts_vertex(e, "Edge--> #{i}")
      end
      puts_edges_global(group)
    end

    def self.puts_edges_global(group)
      tr = group.transformation
      edges = group.entities.grep(Sketchup::Edge)
      puts "---- GLOBAL EDGES OF #{group.name} ----"
      edges.each_with_index do |e, i|
        p1 = e.start.position.transform(tr)
        p2 = e.end.position.transform(tr)
        puts "Edge #{i}:"
        puts "  Start: (#{p1.x.to_mm}, #{p1.y.to_mm}, #{p1.z.to_mm})"
        puts "  End:   (#{p2.x.to_mm}, #{p2.y.to_mm}, #{p2.z.to_mm})"
        len = p1.distance(p2)
        puts "len : #{len}"
      end
    end

    #puts_edges_any(mon_groupe)      #1 groupe
    #puts_edges_any([g1, g2, g3])    #plusieurs groupes
    #puts_edges_any([g1, instance, g2])  #melange    
    def puts_edges_any(group_or_array)
      # Normaliser : toujours travailler avec un tableau
      groups =
      case group_or_array
      when Sketchup::Group, Sketchup::ComponentInstance
        [group_or_array]
      when Array
        group_or_array
      else
        puts "⚠️ unrecognized object / objet non reconnu : #{group_or_array.class}"
        return
      end

      groups.each do |grp|
      unless grp.is_a?(Sketchup::Group) || grp.is_a?(Sketchup::ComponentInstance)
        puts "⚠️ Ignored / Ignoré : #{grp.inspect} not a Group/ComponentInstance"
        next
      end

      puts "---- EDGES OF #{grp.name} ----"
      tr = grp.transformation
      edges = grp.entities.grep(Sketchup::Edge)

      edges.each_with_index do |e, i|
        p1 = e.start.position.transform(tr)
        p2 = e.end.position.transform(tr)

        puts "Edge #{i}:"
        puts "  Start: (#{p1.x.to_mm}, #{p1.y.to_mm}, #{p1.z.to_mm})"
        puts "  End:   (#{p2.x.to_mm}, #{p2.y.to_mm}, #{p2.z.to_mm})"
      end
      end
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
#***********************************************************************************************

  end
end