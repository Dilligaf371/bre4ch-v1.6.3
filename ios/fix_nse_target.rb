#!/usr/bin/env ruby
# Fix duplicate .appex production in Xcode project
require 'xcodeproj'

project_path = File.join(__dir__, 'Runner.xcodeproj')
project = Xcodeproj::Project.open(project_path)

runner = project.targets.find { |t| t.name == 'Runner' }
nse = project.targets.find { |t| t.name == 'NotificationService' }

unless runner && nse
  puts "ERROR: Targets not found"
  exit 1
end

# Remove ALL "Embed App Extensions" phases (we'll recreate one clean one)
runner.copy_files_build_phases.select { |p| p.name == 'Embed App Extensions' }.each do |phase|
  puts "Removing duplicate 'Embed App Extensions' phase"
  phase.remove_from_project
end

# Create a single clean embed phase
embed_phase = runner.new_copy_files_build_phase('Embed App Extensions')
embed_phase.dst_subfolder_spec = '13' # PlugIns
embed_phase.add_file_reference(nse.product_reference, true)
embed_phase.files.each do |file|
  file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end

# Ensure only one dependency
runner_deps = runner.dependencies.select { |d| d.target == nse }
if runner_deps.length > 1
  puts "Removing #{runner_deps.length - 1} duplicate dependencies"
  runner_deps[1..].each { |d| d.remove_from_project }
end

# Fix NotificationService build settings — ensure PRODUCT_NAME is set
nse.build_configurations.each do |config|
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  config.build_settings['SKIP_INSTALL'] = 'YES'
end

project.save
puts "✅ Fixed Xcode project — single clean embed phase"
