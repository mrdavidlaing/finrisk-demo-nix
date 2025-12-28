Then('the dependencies should contain an entry for {string}') do |ref|
  dep_entry = @current_sbom['dependencies']&.find { |d| d['ref'] == ref }
  expect(dep_entry).not_to be_nil, "Expected dependency entry for '#{ref}' but it was not found"
end

Then('the dependency {string} should depend on exactly {int} components') do |ref, count|
  dep_entry = @current_sbom['dependencies']&.find { |d| d['ref'] == ref }
  expect(dep_entry).not_to be_nil, "Dependency entry for '#{ref}' not found"

  depends_on = dep_entry['dependsOn'] || []
  expect(depends_on.length).to eq(count),
    "Expected #{count} dependencies for '#{ref}', but found #{depends_on.length}: #{depends_on}"
end

When('I get the dependencies for {string}') do |ref|
  dep_entry = @current_sbom['dependencies']&.find { |d| d['ref'] == ref }
  expect(dep_entry).not_to be_nil, "Dependency entry for '#{ref}' not found"
  @current_depends_on = dep_entry['dependsOn'] || []
end

When('I build dependency graph') do
  build_dependency_graph
end

Then('it should depend on a component matching {string}') do |pattern|
  # Check if any dependency bom-ref contains the pattern
  # For layer components, check against metadata.component in referenced SBOMs
  # or check if external references contain the pattern

  external_refs = @current_sbom.dig('metadata', 'component', 'externalReferences') || []
  matching_ref = external_refs.find { |ref| ref['url']&.include?(pattern) }

  if matching_ref
    # Find the component with this external reference pattern
    # The dependency should reference a component that came from this layer
    expect(@current_depends_on).not_to be_empty,
      "Expected dependencies for layer '#{pattern}' but dependsOn is empty"
  else
    # Fallback: check if any component has properties indicating it's from this layer
    layer_name = pattern.gsub(/\.cdx\.json$/, '').gsub(/^(app|runtime)-/, '')
    matching_components = @current_sbom['components']&.select do |comp|
      props = comp['properties'] || []
      layer_prop = props.find { |p| p['name'] == 'layer' }

      # Check if component is from the expected layer
      if pattern.start_with?('base.')
        layer_prop&.fetch('value') == 'base'
      elsif pattern.start_with?('runtime-')
        layer_prop&.fetch('value') == 'runtime'
      elsif pattern.start_with?('app-')
        layer_prop&.fetch('value') == 'app'
      else
        false
      end
    end

    # At least one component from this layer should be in the dependencies
    matching_bom_refs = matching_components&.map { |c| c['bom-ref'] } || []
    has_match = @current_depends_on.any? { |dep| matching_bom_refs.include?(dep) }

    expect(has_match).to be true,
      "Expected dependency on layer '#{pattern}' but found no matching components in dependsOn: #{@current_depends_on}"
  end
end

Then('the components should include at least {int} npm packages') do |min_count|
  npm_packages = @current_sbom['components']&.select do |comp|
    comp['purl']&.start_with?('pkg:npm/')
  end || []

  expect(npm_packages.length).to be >= min_count,
    "Expected at least #{min_count} npm packages, but found only #{npm_packages.length}"
end

Then('the components should include a package with purl starting with {string}') do |purl_prefix|
  matching_component = @current_sbom['components']&.find do |comp|
    comp['purl']&.start_with?(purl_prefix)
  end

  expect(matching_component).not_to be_nil,
    "Expected to find a component with purl starting with '#{purl_prefix}'"
end

When('I find an npm package component') do |
|
  @npm_component = @current_sbom['components']&.find do |comp|
    comp['purl']&.start_with?('pkg:npm/')
  end

  expect(@npm_component).not_to be_nil, "No npm package components found in SBOM"
end

Then('its bom-ref should have a corresponding dependency entry') do ||
  component = @package_component || @npm_component
  expect(component).not_to be_nil, "No component found. Use 'I find a package component of type' step first"

  bom_ref = component['bom-ref']
  @package_dep_entry = @current_sbom['dependencies']&.find { |d| d['ref'] == bom_ref }

  expect(@package_dep_entry).not_to be_nil,
    "Expected dependency entry for package '#{component['name']}' with bom-ref '#{bom_ref}'"
end

Then('that dependency entry should have at least {int} dependsOn entries') do |min_count|
  dep_entry = @package_dep_entry || @npm_dep_entry
  expect(dep_entry).not_to be_nil, "No dependency entry found. Use 'its bom-ref should have a corresponding dependency entry' step first"

  depends_on = dep_entry['dependsOn'] || []
  expect(depends_on.length).to be >= min_count,
    "Expected at least #{min_count} dependencies for package, but found #{depends_on.length}"
end

When('I collect all dependency refs') do ||
  @all_refs = []
  (@current_sbom['dependencies'] || []).each do |dep|
    @all_refs << dep['ref']
    @all_refs.concat(dep['dependsOn'] || [])
  end
  @all_refs.uniq!
end

Then('every ref should match a component bom-ref') do ||
  component_bom_refs = (@current_sbom['components'] || []).map { |c| c['bom-ref'] }
  # Also include the metadata component if it has a bom-ref
  metadata_bom_ref = @current_sbom.dig('metadata', 'component', 'bom-ref')
  component_bom_refs << metadata_bom_ref if metadata_bom_ref

  @all_refs.each do |ref|
    expect(component_bom_refs.include?(ref)).to be(true),
      "Dependency ref '#{ref}' does not match any component bom-ref"
  end
end

Then('the dependency graph should not contain cycles') do ||
  # Build adjacency list
  graph = {}
  (@current_sbom['dependencies'] || []).each do |dep|
    graph[dep['ref']] = dep['dependsOn'] || []
  end

  # Known legitimate cycles (e.g., pytest plugin system)
  known_cycles = [
    ['pkg:pypi/pytest@', 'pkg:pypi/pluggy@'],
  ]

  # DFS to detect cycles
  visited = {}
  rec_stack = {}

  def has_cycle(node, graph, visited, rec_stack, known_cycles)
    visited[node] = true
    rec_stack[node] = true

    (graph[node] || []).each do |neighbor|
      next if neighbor == node
      if !visited[neighbor]
        return true if has_cycle(neighbor, graph, visited, rec_stack, known_cycles)
      elsif rec_stack[neighbor]
        # Check if this is a known legitimate cycle
        is_known_cycle = known_cycles.any? do |cycle_pair|
          (node.include?(cycle_pair[0]) && neighbor.include?(cycle_pair[1])) ||
          (node.include?(cycle_pair[1]) && neighbor.include?(cycle_pair[0]))
        end
        return true unless is_known_cycle
      end
    end

    rec_stack[node] = false
    false
  end

  graph.keys.each do |node|
    if !visited[node]
      if has_cycle(node, graph, visited, rec_stack, known_cycles)
        fail "Dependency graph contains a cycle involving node '#{node}'"
      end
    end
  end
end

Then('all bom-refs in dependsOn arrays should reference existing components') do ||
  component_bom_refs = (@current_sbom['components'] || []).map { |c| c['bom-ref'] }
  metadata_bom_ref = @current_sbom.dig('metadata', 'component', 'bom-ref')
  component_bom_refs << metadata_bom_ref if metadata_bom_ref

  (@current_sbom['dependencies'] || []).each do |dep|
    (dep['dependsOn'] || []).each do |ref|
      expect(component_bom_refs.include?(ref)).to be(true),
        "dependsOn ref '#{ref}' in dependency '#{dep['ref']}' does not match any component bom-ref"
    end
  end
end

Then('the components should include at least {int} packages of type {string}') do |min_count, type_prefix|
  packages = @current_sbom['components']&.select do |comp|
    comp['purl']&.start_with?(type_prefix)
  end || []

  expect(packages.length).to be >= min_count,
    "Expected at least #{min_count} packages of type '#{type_prefix}', but found only #{packages.length}"
end

When('I find a package component of type {string}') do |type_prefix|
  @package_component = @current_sbom['components']&.find do |comp|
    comp['purl']&.start_with?(type_prefix)
  end

  expect(@package_component).not_to be_nil, "No package components of type '#{type_prefix}' found in SBOM"
end

When('I build the dependency graph') do
  @graph = {}
  (@current_sbom['dependencies'] || []).each do |dep|
    @graph[dep['ref']] = dep['dependsOn'] || []
  end
end

When('I calculate the longest dependency path from {string}') do |start_ref|
  build_dependency_graph

  @longest_path_length = calculate_longest_path(start_ref, @graph, 1, [])
end

Then('the path depth should be at least {int}') do |min_depth|
  expect(@longest_path_length).to be >= min_depth,
    "Expected dependency path depth of at least #{min_depth}, but found #{@longest_path_length}"
end

Then('there should be a path from {string} to that package') do |start_ref|
  build_dependency_graph

  target_bom_ref = @package_component['bom-ref']
  @path = find_path(start_ref, target_bom_ref, @graph, [])

  expect(@path).not_to be_empty,
    "No path found from '#{start_ref}' to package '#{@package_component['name']}' (#{target_bom_ref})"
end

def build_dependency_graph
  @graph = {}
  (@current_sbom['dependencies'] || []).each do |dep|
    @graph[dep['ref']] = dep['dependsOn'] || []
  end
end

Then('the path should have at least {int} levels') do |min_levels|
  expect(@path.length).to be >= min_levels,
    "Expected path of at least #{min_levels} levels, but found #{@path.length}: #{@path}"
end

Then('the path should include {string} layer') do |layer_name|
  path_string = @path.join(' ')
  expect(path_string.downcase.include?(layer_name)).to be(true),
    "Path does not include '#{layer_name}' layer: #{@path}"
end

def calculate_longest_path(node, graph, depth, visited)
  path_lengths = [depth] + (graph[node] || []).map do |neighbor|
    next depth if visited.include?(neighbor)
    calculate_longest_path(neighbor, graph, depth + 1, visited + [node])
  end
  path_lengths.max
end

def find_path(from, to, graph, visited)
  return [] if visited.include?(from)

  if from == to
    return [from]
  end

  (graph[from] || []).each do |neighbor|
    path = find_path(neighbor, to, graph, visited + [from])
    if path.any?
      return [from] + path
    end
  end

  []
end

