Then('the SBOM should have a compositions section') do
  compositions = @current_sbom['compositions']
  expect(compositions).not_to be_nil, "SBOM has no compositions section"
  expect(compositions).to be_an(Array), "Compositions is not an array"
  expect(compositions).not_to be_empty, "Compositions array is empty"
end

Then('the compositions should include aggregate {string}') do |expected_aggregate|
  compositions = @current_sbom['compositions'] || []
  aggregates = compositions.map { |c| c['aggregate'] }.compact

  expect(aggregates.include?(expected_aggregate)).to be(true),
    "Expected aggregate '#{expected_aggregate}', but found: #{aggregates.join(', ')}"
end

Then('the compositions should reference:') do |table|
  compositions = @current_sbom['compositions'] || []

  # Get all assembly refs from compositions (they're strings, not objects)
  all_assembly_refs = compositions.flat_map do |composition|
    composition['assemblies'] || []
  end.compact

  # For now, this test expects SBOM file refs like "base.cdx.json",
  # but current implementation uses Nix derivation paths.
  # This is an @current_state test that will be replaced by @enforce_fix version
  table.raw.flatten.each do |expected_ref|
    # Check if any assembly path contains the expected filename
    found = all_assembly_refs.any? { |ref| ref.include?(expected_ref) || ref.end_with?(expected_ref) }
    expect(found).to be(true),
      "Expected composition reference containing '#{expected_ref}', but found: #{all_assembly_refs.join(', ')}"
  end
end

When('I find the component {string}') do |component_name|
  @found_component = SBOMLoader.find_component(@current_sbom, component_name)
end

Then('the component should have property {string} with value {string}') do |property_name, expected_value|
  pending "Component not found" if @found_component.nil?

  properties = @found_component['properties'] || []
  matching_property = properties.find { |p| p['name'] == property_name }

  expect(matching_property).not_to be_nil,
    "Component does not have property '#{property_name}'"

  expect(matching_property['value']).to eq(expected_value),
    "Expected property '#{property_name}' to have value '#{expected_value}', got '#{matching_property['value']}'"
end

Then('the component should NOT have property {string}') do |property_name|
  pending "Component not found" if @found_component.nil?

  properties = @found_component['properties'] || []
  matching_property = properties.find { |p| p['name'] == property_name }

  expect(matching_property).to be_nil,
    "Component should not have property '#{property_name}', but it does with value: #{matching_property['value']}"
end
