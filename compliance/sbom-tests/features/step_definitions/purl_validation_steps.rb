Then('all components with type {string} should have a PURL') do |component_type|
  @container_sboms.each do |path, sbom|
    components = SBOMLoader.components(sbom)
    typed_components = components.select { |c| c['type'] == component_type }

    missing_purl = typed_components.select { |c| c['purl'].nil? || c['purl'].empty? }

    expect(missing_purl).to be_empty,
      "Found #{missing_purl.length} #{component_type} components without PURLs in #{File.basename(path)}"
  end
end

When('I find all components with PURL type {string}') do |purl_type|
  @purl_type = purl_type
  @components_by_type = []

  @container_sboms.each do |sbom_path, sbom|
    components = SBOMLoader.components(sbom)
    components.each do |component|
      purl = component['purl']
      next if purl.nil?

      parsed = PURLValidator.parse(purl)
      if parsed && parsed[:type] == purl_type
        @components_by_type << { sbom: sbom_path, component: component, purl: purl }
      end
    end
  end
end

Then('all PURLs should match the pattern {string}') do |pattern|
  regex = Regexp.new(pattern)

  mismatches = @components_by_type.select do |item|
    !regex.match?(item[:purl])
  end

  expect(mismatches).to be_empty,
    "Found #{mismatches.length} PURLs that don't match pattern #{pattern}:\n" +
    mismatches.first(5).map { |m| "  #{m[:purl]}" }.join("\n")
end

Then('all PURLs should have a name') do
  missing_name = @components_by_type.select do |item|
    parsed = PURLValidator.parse(item[:purl])
    parsed.nil? || parsed[:name].nil? || parsed[:name].empty?
  end

  expect(missing_name).to be_empty,
    "Found #{missing_name.length} PURLs without names"
end

Then('all PURLs should have a version') do
  missing_version = @components_by_type.select do |item|
    parsed = PURLValidator.parse(item[:purl])
    parsed.nil? || parsed[:version].nil? || parsed[:version].empty?
  end

  expect(missing_version).to be_empty,
    "Found #{missing_version.length} PURLs without versions"
end

When('I find the component {string} in any SBOM') do |component_name|
  @found_component = nil
  @found_sbom_path = nil

  @container_sboms.each do |sbom_path, sbom|
    component = SBOMLoader.find_component(sbom, component_name)
    if component
      @found_component = component
      @found_sbom_path = sbom_path
      break
    end
  end

  # Don't fail if not found - component may not exist in this build
  # The scenario will skip if component is nil
end

Then('the PURL type should be {string}') do |expected_type|
  pending "Component not found in any SBOM" if @found_component.nil?

  purl = @found_component['purl']
  expect(purl).not_to be_nil, "Component has no PURL"

  parsed = PURLValidator.parse(purl)
  expect(parsed).not_to be_nil, "PURL is invalid: #{purl}"

  expect(parsed[:type]).to eq(expected_type),
    "Expected PURL type '#{expected_type}', got '#{parsed[:type]}' for #{purl}"
end

Then('all instances should have PURL type {string}') do |expected_type|
  purls = @found_components.map { |fc| fc[:component]['purl'] }.compact

  purls.each do |purl|
    parsed = PURLValidator.parse(purl)
    expect(parsed).not_to be_nil, "Invalid PURL: #{purl}"
    expect(parsed[:type]).to eq(expected_type),
      "Expected type '#{expected_type}', got '#{parsed[:type]}' for #{purl}"
  end
end
