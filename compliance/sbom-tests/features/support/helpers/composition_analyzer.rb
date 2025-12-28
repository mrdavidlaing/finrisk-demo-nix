# Composition Analyzer - Analyze CycloneDX compositions and trace provenance
class CompositionAnalyzer
  # Get compositions from an SBOM
  def self.compositions(sbom)
    sbom['compositions'] || []
  end

  # Get assemblies from first composition
  def self.assemblies(sbom)
    first_composition = compositions(sbom).first
    return [] unless first_composition
    first_composition['assemblies'] || []
  end

  # Get external references from metadata
  def self.external_references(sbom)
    metadata = sbom['metadata'] || {}
    component = metadata['component'] || {}
    component['externalReferences'] || []
  end

  # Get BOM-type external references
  def self.bom_references(sbom)
    external_references(sbom).select { |ref| ref['type'] == 'bom' }
  end

  # Trace a component to its source SBOM
  # Returns: { found: boolean, source_sbom: path, component: data }
  def self.trace_component(component_name, container_sbom, source_sboms)
    # Look for component in each source SBOM
    source_sboms.each do |source_path, source_sbom|
      component = SBOMLoader.find_component(source_sbom, component_name)
      if component
        return {
          found: true,
          source_sbom: source_path,
          component: component
        }
      end
    end

    # Not found in any source
    { found: false, source_sbom: nil, component: nil }
  end

  # Check if all components in container SBOM can be traced to source SBOMs
  def self.all_traceable?(container_sbom, source_sboms)
    components = SBOMLoader.components(container_sbom)
    components.all? do |component|
      name = component['name']
      result = trace_component(name, container_sbom, source_sboms)
      result[:found]
    end
  end

  # Get orphaned components (in container but not in any source)
  def self.orphaned_components(container_sbom, source_sboms)
    components = SBOMLoader.components(container_sbom)
    components.select do |component|
      name = component['name']
      result = trace_component(name, container_sbom, source_sboms)
      !result[:found]
    end
  end

  # Check if component has layer provenance tag
  def self.has_layer_tag?(component)
    properties = component['properties'] || []
    properties.any? { |p| p['name'] == 'cdx:layer' || p['name'] == 'sbom:source' || p['name'] == 'layer' }
  end

  # Get layer from component properties
  def self.layer(component)
    properties = component['properties'] || []
    layer_prop = properties.find { |p| p['name'] == 'cdx:layer' || p['name'] == 'sbom:source' || p['name'] == 'layer' }
    layer_prop ? layer_prop['value'] : nil
  end
end
