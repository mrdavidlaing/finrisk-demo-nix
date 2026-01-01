When('I find all {string} packages') do |purl_prefix|
  @ecosystem_packages = @current_sbom['components']&.select do |comp|
    comp['purl']&.start_with?(purl_prefix)
  end || []
  
  expect(@ecosystem_packages).not_to be_empty,
    "No packages found with purl prefix '#{purl_prefix}' in #{@sbom_file}"
end

Then('each package should have a {string} property') do |prop_name|
  missing = @ecosystem_packages.reject do |comp|
    props = comp['properties'] || []
    props.any? { |p| p['name'] == prop_name }
  end
  
  if missing.any?
    missing_purls = missing.map { |c| c['purl'] }.first(5).join(', ')
    expect(missing).to be_empty,
      "#{missing.length} packages missing '#{prop_name}' property: #{missing_purls}"
  end
end

Then('each package should have an externalReference of type {string}') do |ref_type|
  missing = @ecosystem_packages.reject do |comp|
    refs = comp['externalReferences'] || []
    refs.any? { |r| r['type'] == ref_type }
  end
  
  if missing.any?
    missing_purls = missing.map { |c| c['purl'] }.first(5).join(', ')
    expect(missing).to be_empty,
      "#{missing.length} packages missing externalReference type '#{ref_type}': #{missing_purls}"
  end
end

When('I find all {string} packages with {string} property') do |purl_prefix, prop_name|
  @mapped_packages = @current_sbom['components']&.select do |comp|
    has_purl = comp['purl']&.start_with?(purl_prefix)
    has_prop = (comp['properties'] || []).any? { |p| p['name'] == prop_name }
    has_purl && has_prop
  end || []
  
  # If no mapped packages found, that's ok for unmappable ecosystems
  # The test scenario will still run but pass vacuously
end

Then('there should be no component with that {string} as its primary purl') do |prop_name|
  @mapped_packages.each do |pkg|
    nix_purl_prop = (pkg['properties'] || []).find { |p| p['name'] == prop_name }
    nix_purl = nix_purl_prop&.dig('value')
    next unless nix_purl
    
    duplicate = @current_sbom['components']&.find { |c| c['purl'] == nix_purl }
    expect(duplicate).to be_nil,
      "Found duplicate Nix component with purl '#{nix_purl}' that should have been merged into '#{pkg['purl']}'"
  end
end

# NEW STEPS FOR SCOPE METADATA AND 100% TRACEABILITY

When('I filter packages by property {string} with value {string}') do |prop_name, prop_value|
  @filtered_packages = @ecosystem_packages.select do |pkg|
    pkg['properties']&.any? { |p| p['name'] == prop_name && p['value'] == prop_value }
  end
end

Then('the package count should be at least {int}') do |min_count|
  actual_count = @filtered_packages.length
  expect(actual_count).to be >= min_count,
    "Expected at least #{min_count} packages with the filter, but got #{actual_count}"
end

Then('each package should have scope {string} at component level') do |expected_scope|
  @filtered_packages.each do |pkg|
    expect(pkg['scope']).to eq(expected_scope),
      "Package #{pkg['name']} has scope '#{pkg['scope']}' but expected '#{expected_scope}'"
  end
end

Then('the package list should include {string}') do |expected_name|
  names = @filtered_packages.map { |p| p['name'] }
  expect(names).to(include(expected_name))
end

Then('all packages should have {string} property') do |prop_name|
  missing = @ecosystem_packages.reject do |pkg|
    pkg['properties']&.any? { |p| p['name'] == prop_name }
  end
  
  expect(missing).to be_empty,
    "#{missing.length} packages missing '#{prop_name}' property"
end

Then('the traceability coverage should be {int}%') do |expected_percentage|
  total = @ecosystem_packages.length
  with_traceability = @ecosystem_packages.count do |pkg|
    pkg['properties']&.any? { |p| p['name'] == 'nix:output' }
  end
  
  actual_percentage = (with_traceability.to_f / total * 100).round
  expect(actual_percentage).to eq(expected_percentage),
    "Traceability coverage is #{actual_percentage}% (#{with_traceability}/#{total}), expected #{expected_percentage}%"
end

When('I extract all {string} property values') do |prop_name|
  @property_values = @ecosystem_packages.flat_map do |pkg|
    pkg['properties']&.select { |p| p['name'] == prop_name }&.map { |p| p['value'] } || []
  end
end

Then('each value should start with {string}') do |prefix|
  @property_values.each do |value|
    expect(value).to start_with(prefix),
      "Value '#{value}' does not start with '#{prefix}'"
  end
end

Then('each value should contain {string}') do |substring|
  @property_values.each do |value|
    expect(value).to(include(substring))
  end
end

Then('each package should have an externalReference with URL starting with {string}') do |url_prefix|
  @ecosystem_packages.each do |pkg|
    ext_refs = pkg['externalReferences'] || []
    matching_ref = ext_refs.any? do |ref|
      ref['url']&.start_with?(url_prefix)
    end
    
    expect(matching_ref).to be true
  end
end
