# Localization project wiring — idempotent.
#   bundle exec ruby scripts/localization_setup.rb
#
# 1. Adds 'uk' to the project's knownRegions.
# 2. Adds GymJamWatch/Localizable.xcstrings to the Watch target (the
#    Watch group is a classic PBXGroup — files don't auto-join like the
#    filesystem-synchronized GymBro/GymJamWidgets groups do).

require 'xcodeproj'

project_path = File.expand_path(File.join(__dir__, '..', 'GymBro.xcodeproj'))
project = Xcodeproj::Project.open(project_path)

changed = false

# ── knownRegions ─────────────────────────────────────────────
%w[en Base uk].each do |region|
  unless project.root_object.known_regions.include?(region)
    project.root_object.known_regions << region
    puts "knownRegions += #{region}"
    changed = true
  end
end

# ── Watch catalog wiring ─────────────────────────────────────
watch_group = project.main_group.children.find do |child|
  child.is_a?(Xcodeproj::Project::Object::PBXGroup) &&
    (child.name == 'GymJamWatch' || child.path == 'GymJamWatch')
end
abort('GymJamWatch group not found') unless watch_group

existing_ref = watch_group.files.find { |f| f.path&.end_with?('Localizable.xcstrings') }
if existing_ref
  puts 'Watch catalog file ref already present'
  file_ref = existing_ref
else
  file_ref = watch_group.new_reference('Localizable.xcstrings')
  puts 'Added Watch catalog file ref'
  changed = true
end

watch_target = project.targets.find { |t| t.name == 'GymJamWatch' }
abort('GymJamWatch target not found') unless watch_target

in_resources = watch_target.resources_build_phase.files_references.include?(file_ref)
unless in_resources
  watch_target.add_resources([file_ref])
  puts 'Added catalog to Watch Resources phase'
  changed = true
end

if changed
  project.save
  puts 'Project saved.'
else
  puts 'No changes needed.'
end
