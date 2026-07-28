module Auvent
	module Hierarchy
		def self.printHierarchy
			#answer = UI.messagebox("Print Hierarchy to Ruby Console?", MB_YESNO)
			#	if answer == 6
					model = Sketchup.active_model
					h = ModelHierarchy.new(model)
					h.print_hierarchy(model)
					puts("-------------------------------------------")
			#	end
			# end
		end
		
		class ModelHierarchy
			attr_accessor :definition, :children, :polygons
			def initialize(model)
				@definition = {}
				@children   = {}
				@polygons   = {}
				model.definitions.each do |comp|
					@polygons[comp] = 0
					# Compter les faces
					comp.entities.each do |e|
						@polygons[comp] += 1 if e.is_a?(Sketchup::Face)
					end
					# Enregistrer les instances
					comp.instances.each do |inst|
						@definition[inst] = comp
						parent = inst.parent
						@children[parent] ||= []
						@children[parent] << inst
					end
				end
			end

			def print_hierarchy(key, level = 0)
				if key.is_a?(Sketchup::Model)
					puts "Model #{key.title} [#{key.entities.grep(Sketchup::Face).length} polygons]"
				end
				return unless @children.has_key?(key)
				@children[key].each do |inst|
					name = inst.name
					name = "Instance of #{@definition[inst].name}" if name.empty?
					print "···" * level
					puts "|---#{name} (#{inst.typename}) [#{@polygons[@definition[inst]]} polygons]"
					print_hierarchy(@definition[inst], level + 1)
				end
			end
		end
	end
end
