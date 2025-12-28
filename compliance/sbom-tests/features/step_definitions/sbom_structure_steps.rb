Given('the SBOM directory {string} exists') do |dir|
  @sbom_dir = File.expand_path(dir, PROJECT_ROOT)
  expect(Dir.exist?(@sbom_dir)).to be(true), "SBOM directory not found: #{@sbom_dir}"
end

Given('I load the SBOM file {string}') do |file_path|
  full_path = File.expand_path(file_path, PROJECT_ROOT)
  @current_sbom = SBOMLoader.load(full_path)
  @current_sbom_path = file_path
end

Then('the following SBOM files should exist:') do |table|
  table.hashes.each do |row|
    pattern = File.join(@sbom_dir, row['file_pattern'])
    files = Dir.glob(pattern)
    expect(files).not_to be_empty,
      "No #{row['sbom_type']} SBOM files found matching pattern: #{pattern}"
  end
end

Then('the SBOM should have bomFormat {string}') do |expected_format|
  expect(@current_sbom['bomFormat']).to eq(expected_format),
    "Expected bomFormat '#{expected_format}', got '#{@current_sbom['bomFormat']}'"
end

Then('the SBOM should have specVersion {string}') do |expected_version|
  expect(@current_sbom['specVersion']).to eq(expected_version),
    "Expected specVersion '#{expected_version}', got '#{@current_sbom['specVersion']}'"
end

Then('the SBOM should have a valid serialNumber') do
  serial_number = @current_sbom['serialNumber']
  expect(serial_number).not_to be_nil, "serialNumber is missing"
  expect(serial_number).to match(/^urn:uuid:[0-9a-f-]+$/),
    "serialNumber '#{serial_number}' is not a valid UUID URN"
end

Then('the metadata component type should be {string}') do |expected_type|
  metadata = @current_sbom['metadata'] || {}
  component = metadata['component'] || {}
  actual_type = component['type']
  expect(actual_type).to eq(expected_type),
    "Expected metadata component type '#{expected_type}', got '#{actual_type}'"
end

Then('the metadata component name should match {string}') do |expected_name|
  metadata = @current_sbom['metadata'] || {}
  component = metadata['component'] || {}
  actual_name = component['name']
  expect(actual_name).to eq(expected_name),
    "Expected metadata component name '#{expected_name}', got '#{actual_name}'"
end

Then('the metadata should contain externalReferences to:') do |table|
  metadata = @current_sbom['metadata'] || {}
  component = metadata['component'] || {}
  external_refs = component['externalReferences'] || []

  bom_refs = external_refs.select { |ref| ref['type'] == 'bom' }
  bom_urls = bom_refs.map { |ref| ref['url'] }

  table.raw.flatten.each do |expected_url|
    expect(bom_urls.include?(expected_url)).to be(true),
      "Expected externalReference to '#{expected_url}', but found: #{bom_urls.join(', ')}"
  end
end

Then('the components should include:') do |table|
  components = @current_sbom['components'] || []

  table.hashes.each do |expected|
    found = components.any? do |component|
      component['name'] == expected['name'] && component['type'] == expected['type']
    end

    expect(found).to be(true),
      "Expected component #{expected['name']} (#{expected['type']}) not found in SBOM"
  end
end
