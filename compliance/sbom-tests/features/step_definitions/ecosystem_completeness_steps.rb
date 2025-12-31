Then('the components should include a package with purl {string}') do |expected_purl|
  matching_component = @current_sbom['components']&.find do |comp|
    comp['purl'] == expected_purl
  end

  expect(matching_component).not_to be_nil,
    "Expected to find component with purl '#{expected_purl}'"
end

Then('there should be at least {int} components with purl starting with {string}') do |min_count, type_prefix|
  matching_count = @current_sbom['components']&.count do |comp|
    comp['purl']&.start_with?(type_prefix)
  end || 0

  expect(matching_count).to be >= min_count,
    "Expected at least #{min_count} components with purl starting with '#{type_prefix}', but found #{matching_count}"
end

Then('there should be dependency entries for all Maven packages') do
  maven_components = @current_sbom['components']&.select do |comp|
    comp['purl']&.start_with?('pkg:maven/')
  end || []

  maven_bom_refs = maven_components.map { |c| c['bom-ref'] }

  maven_bom_refs.each do |bom_ref|
    dep_entry = @current_sbom['dependencies']&.find { |d| d['ref'] == bom_ref }
    expect(dep_entry).not_to be_nil,
      "Maven package with bom-ref '#{bom_ref}' has no corresponding dependency entry"
  end
end

Then('the dependency graph should not be empty for package type {string}') do |type_prefix|
  package_deps = @current_sbom['dependencies']&.select do |dep|
    dep['ref']&.start_with?(type_prefix)
  end || []

  expect(package_deps.length).to be > 0,
    "Expected at least one dependency entry for package type '#{type_prefix}', but found none"
end

Then('there should be at least {int} dependency entries for packages of type {string}') do |min_count, type_prefix|
  package_deps = @current_sbom['dependencies']&.select do |dep|
    dep['ref']&.start_with?(type_prefix)
  end || []

  expect(package_deps.length).to be >= min_count,
    "Expected at least #{min_count} dependency entries for package type '#{type_prefix}', but found #{package_deps.length}"
end

Then('there should be at least one {string} package with non-empty dependsOn') do |type_prefix|
  package_with_deps = @current_sbom['dependencies']&.find do |dep|
    dep['ref']&.start_with?(type_prefix) && (dep['dependsOn'] || []).length > 0
  end

  expect(package_with_deps).not_to be_nil,
    "Expected at least one #{type_prefix} package with non-empty dependsOn array, but found none"
end

Then('there should be at least one npm package with non-empty dependsOn') do
  package_with_deps = @current_sbom['dependencies']&.find do |dep|
    dep['ref']&.start_with?('pkg:npm/') && (dep['dependsOn'] || []).length > 0
  end

  expect(package_with_deps).not_to be_nil,
    "Expected at least one npm package with non-empty dependsOn array, but found none"
end

Then('there should be at least one cargo package with non-empty dependsOn') do
  package_with_deps = @current_sbom['dependencies']&.find do |dep|
    dep['ref']&.start_with?('pkg:cargo/') && (dep['dependsOn'] || []).length > 0
  end

  expect(package_with_deps).not_to be_nil,
    "Expected at least one cargo package with non-empty dependsOn array, but found none"
end

Then('the dependency graph should have depth greater than {int}') do |min_depth|
  # Ensure graph is built from existing step in dependency_graph_steps.rb
  @graph ||= {}
  (@current_sbom['dependencies'] || []).each do |dep|
    @graph[dep['ref']] = dep['dependsOn'] || []
  end

  max_depth = 0
  @graph.each do |node, deps|
    depth = calculate_longest_path(node, @graph, 1, [])
    max_depth = depth if depth > max_depth
  end

  expect(max_depth).to be > min_depth,
    "Expected dependency graph depth greater than #{min_depth}, but found #{max_depth}"
end

Then('the components should include at least {int} Maven packages') do |min_count|
  maven_count = @current_sbom['components']&.count do |comp|
    comp['purl']&.start_with?('pkg:maven/')
  end || 0

  expect(maven_count).to be >= min_count,
    "Expected at least #{min_count} Maven packages, but found #{maven_count}"
end

# Helper methods
def calculate_longest_path(node, graph, depth, visited)
  return depth if visited.include?(node)

  path_lengths = [depth] + (graph[node] || []).map do |neighbor|
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
