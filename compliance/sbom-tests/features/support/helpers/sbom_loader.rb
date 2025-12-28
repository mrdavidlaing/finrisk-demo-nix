# SBOM Loader - Load and parse CycloneDX SBOM files
class SBOMLoader
  # Load a single SBOM file
  def self.load(file_path)
    JSON.parse(File.read(file_path))
  rescue JSON::ParserError => e
    raise "Invalid JSON in #{file_path}: #{e.message}"
  rescue Errno::ENOENT
    raise "SBOM file not found: #{file_path}"
  end

  # Load all SBOMs matching a glob pattern
  def self.load_all_matching(pattern)
    Dir.glob(pattern).sort.each_with_object({}) do |file, hash|
      hash[file] = load(file)
    end
  end

  # Get all components from an SBOM
  def self.components(sbom)
    sbom['components'] || []
  end

  # Find a component by name in an SBOM
  def self.find_component(sbom, name)
    components(sbom).find { |c| c['name'] == name }
  end

  # Find all components by name across multiple SBOMs
  def self.find_all_components(sboms, name)
    results = []
    sboms.each do |sbom_path, sbom|
      components(sbom).select { |c| c['name'] == name }.each do |component|
        results << { sbom: sbom_path, component: component }
      end
    end
    results
  end
end
