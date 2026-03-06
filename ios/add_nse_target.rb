#!/usr/bin/env ruby
# Adds Notification Service Extension target to the Xcode project
require 'xcodeproj'

project_path = File.join(__dir__, 'Runner.xcodeproj')
project = Xcodeproj::Project.open(project_path)

# Check if target already exists
if project.targets.any? { |t| t.name == 'NotificationService' }
  puts "NotificationService target already exists, skipping."
  exit 0
end

# Get Runner target for reference
runner = project.targets.find { |t| t.name == 'Runner' }
unless runner
  puts "ERROR: Runner target not found"
  exit 1
end

# Get the Runner's deployment target
runner_deployment_target = runner.build_configurations.first.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] || '16.0'

# Get Runner's team and code signing identity
runner_team = runner.build_configurations.first.build_settings['DEVELOPMENT_TEAM']
runner_code_sign = runner.build_configurations.first.build_settings['CODE_SIGN_IDENTITY']

# Create NSE target
nse_target = project.new_target(
  :app_extension,
  'NotificationService',
  :ios,
  runner_deployment_target
)

# Set the product name
nse_target.product_name = 'NotificationService'

# Create a group for the NSE files
nse_group = project.main_group.new_group('NotificationService', 'NotificationService')

# Add source files
swift_ref = nse_group.new_file('NotificationService/NotificationService.swift')
nse_target.source_build_phase.add_file_reference(swift_ref)

# Add Info.plist
plist_ref = nse_group.new_file('NotificationService/Info.plist')

# Configure build settings for all configurations
nse_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.qyber.breachV2.NotificationService'
  config.build_settings['INFOPLIST_FILE'] = 'NotificationService/Info.plist'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['MARKETING_VERSION'] = '1.0'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = runner_deployment_target

  # Copy team from Runner
  if runner_team
    config.build_settings['DEVELOPMENT_TEAM'] = runner_team
  end
  if runner_code_sign
    config.build_settings['CODE_SIGN_IDENTITY'] = runner_code_sign
  end
end

# Add NSE as dependency of Runner (embed in app)
runner.add_dependency(nse_target)

# Embed the extension in the Runner app
embed_phase = runner.new_copy_files_build_phase('Embed App Extensions')
embed_phase.dst_subfolder_spec = '13' # PlugIns folder
embed_phase.add_file_reference(nse_target.product_reference, true)

# Set the copy phase attributes (code sign on copy)
embed_phase.files.each do |file|
  file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end

project.save

puts "✅ NotificationService target added successfully!"
puts "   Bundle ID: com.qyber.breachV2.NotificationService"
puts "   Team: #{runner_team || 'AUTO'}"
puts "   Deployment Target: #{runner_deployment_target}"
