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
