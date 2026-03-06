#!/usr/bin/env ruby
# Fix NSE file reference paths (double-nested NotificationService)
require 'xcodeproj'

project_path = File.join(__dir__, 'Runner.xcodeproj')
project = Xcodeproj::Project.open(project_path)

nse = project.targets.find { |t| t.name == 'NotificationService' }
unless nse
  puts "ERROR: NotificationService target not found"
  exit 1
end

# Find the NotificationService group
nse_group = project.main_group.children.find { |g| g.display_name == 'NotificationService' }

if nse_group
  puts "Found NotificationService group, path: #{nse_group.path}"

  # Remove old group entirely
  nse_group.remove_from_project
  puts "Removed old group"
end

# Clear existing source build phase files
nse.source_build_phase.files.each { |f| f.remove_from_project }
puts "Cleared source build phase"

# Create new group with correct path
new_group = project.main_group.new_group('NotificationService', 'NotificationService')
# Set the group's source_tree to be relative to project
new_group.source_tree = '<group>'

# Add the Swift file with just the filename (group path provides the directory)
swift_ref = new_group.new_reference('NotificationService.swift')
swift_ref.source_tree = '<group>'
nse.source_build_phase.add_file_reference(swift_ref)

# Add Info.plist reference
plist_ref = new_group.new_reference('Info.plist')
plist_ref.source_tree = '<group>'

# Fix INFOPLIST_FILE path in build settings
nse.build_configurations.each do |config|
  config.build_settings['INFOPLIST_FILE'] = 'NotificationService/Info.plist'
end

project.save
puts "✅ Fixed NSE file paths"
