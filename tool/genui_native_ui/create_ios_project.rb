require 'fileutils'
require 'xcodeproj'

# Use the Ruby environment already supplied by CocoaPods. Generates only an
# ignored, separate UI-test runner project; the product Xcode project is untouched.
destination, team = ARGV
abort 'Usage: create_ios_project.rb OUTPUT_DIRECTORY SIGNING_TEAM' unless destination && team
FileUtils.mkdir_p(destination)
source = File.join(destination, 'GenUiGestureTests.swift')
FileUtils.cp(File.join(__dir__, 'ios_gestures.swift'), source)
project = Xcodeproj::Project.new(File.join(destination, 'GenUiGestures.xcodeproj'))
target = project.new_target(:ui_test_bundle, 'GenUiGestures', :ios, '18.0')
target.source_build_phase.add_file_reference(project.main_group.new_file('GenUiGestureTests.swift'))
target.build_configurations.each do |config|
  config.build_settings.merge!({
    'PRODUCT_BUNDLE_IDENTIFIER' => 'psyche.kelivo.genuiacceptance.GestureTests',
    'DEVELOPMENT_TEAM' => team,
    'CODE_SIGN_STYLE' => 'Automatic',
    'GENERATE_INFOPLIST_FILE' => 'YES',
    'SWIFT_VERSION' => '5.0',
    'TARGETED_DEVICE_FAMILY' => '1,2',
  })
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.add_test_target(target)
scheme.save_as(project.path, 'GenUiGestures', true)
