require 'json'
require 'rspec/expectations'

PROJECT_ROOT = File.expand_path('../../../..', __dir__)
SBOM_DIR = File.join(PROJECT_ROOT, 'compliance/sboms')

# Load helpers
Dir[File.join(__dir__, 'helpers', '*.rb')].each { |file| require file }

# World state
World do
  @sbom_dir = SBOM_DIR
  @current_sbom = nil
  @current_sbom_path = nil
  @container_sboms = {}
  @found_components = []
  @current_component = nil
  self
end
