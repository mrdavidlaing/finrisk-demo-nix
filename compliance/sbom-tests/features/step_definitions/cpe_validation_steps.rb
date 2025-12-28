Then('at least {int}% of components should have CPE identifiers') do |min_percentage|
  total_components = 0
  components_with_cpe = 0

  @examined_files.each do |file_path|
    sbom = SBOMLoader.load(file_path)
    components = SBOMLoader.components(sbom)
    total_components += components.length

    components.each do |component|
      cpe = component['cpe']
      components_with_cpe += 1 if cpe && !cpe.empty?
    end
  end

  actual_percentage = (components_with_cpe.to_f / total_components * 100).round(2)

  expect(actual_percentage).to be >= min_percentage,
    "Expected at least #{min_percentage}% of components to have CPEs, but got #{actual_percentage}% " +
    "(#{components_with_cpe}/#{total_components})"
end

Then('all CPEs should match format {string}') do |_format_description|
  invalid_cpes = []

  @examined_files.each do |file_path|
    sbom = SBOMLoader.load(file_path)
    components = SBOMLoader.components(sbom)

    components.each do |component|
      cpe = component['cpe']
      next if cpe.nil? || cpe.empty?

      unless CPEValidator.valid_format?(cpe)
        invalid_cpes << {
          sbom: File.basename(file_path),
          component: component['name'],
          cpe: cpe
        }
      end
    end
  end

  expect(invalid_cpes).to be_empty,
    "Found #{invalid_cpes.length} components with invalid CPE format:\n" +
    invalid_cpes.first(10).map { |c| "  #{c[:sbom]}: #{c[:component]} - #{c[:cpe]}" }.join("\n")
end

When('I extract the CPE') do
  pending "Component not found" if @found_component.nil?

  cpe = @found_component['cpe']
  expect(cpe).not_to be_nil, "Component has no CPE"
  expect(cpe).not_to be_empty, "Component CPE is empty"

  @current_cpe = CPEValidator.parse(cpe)
  expect(@current_cpe).not_to be_nil, "CPE format is invalid: #{cpe}"
end

Then('the CPE vendor should be {string}') do |expected_vendor|
  pending "No CPE extracted" if @current_cpe.nil?

  expect(@current_cpe[:vendor]).to eq(expected_vendor),
    "Expected CPE vendor '#{expected_vendor}', got '#{@current_cpe[:vendor]}'"
end

Then('the CPE product should be {string}') do |expected_product|
  pending "No CPE extracted" if @current_cpe.nil?

  expect(@current_cpe[:product]).to eq(expected_product),
    "Expected CPE product '#{expected_product}', got '#{@current_cpe[:product]}'"
end

When('I extract the CPE version') do
  pending "Component not found" if @found_component.nil?

  cpe = @found_component['cpe']
  expect(cpe).not_to be_nil, "Component has no CPE"

  parsed = CPEValidator.parse(cpe)
  expect(parsed).not_to be_nil, "CPE format is invalid: #{cpe}"

  @current_cpe_version = parsed[:version]
end

Then('the version should match pattern {string}') do |pattern|
  pending "No CPE version extracted" if @current_cpe_version.nil?

  regex = Regexp.new(pattern)
  expect(regex.match?(@current_cpe_version)).to be(true),
    "Expected version '#{@current_cpe_version}' to match pattern '#{pattern}'"
end

Then('the version should NOT match pattern {string}') do |pattern|
  pending "No CPE version extracted" if @current_cpe_version.nil?

  regex = Regexp.new(pattern)
  expect(regex.match?(@current_cpe_version)).to be(false),
    "Expected version '#{@current_cpe_version}' to NOT match pattern '#{pattern}'"
end

When('I normalize the CPE vendor to {string}') do |new_vendor|
  pending "No CPE extracted" if @current_cpe.nil?

  @current_cpe[:vendor] = new_vendor
  @normalized_cpe = "cpe:2.3:#{@current_cpe[:part]}:#{new_vendor}:#{@current_cpe[:product]}:#{@current_cpe[:version]}"
end

When('I remove Nix suffix from CPE version') do
  pending "No CPE extracted" if @current_cpe.nil?

  # Remove Nix package suffix (e.g., 2.40-66 -> 2.40)
  version = @current_cpe[:version]
  normalized_version = version.sub(/-[0-9]+$/, '')

  @current_cpe[:version] = normalized_version
  @normalized_cpe = "cpe:2.3:#{@current_cpe[:part]}:#{@current_cpe[:vendor]}:#{@current_cpe[:product]}:#{normalized_version}"
end

Then('the CPE should exist in NVD database') do
  pending "No normalized CPE" if @normalized_cpe.nil?

  require 'net/http'
  require 'uri'
  require 'json'

  # NVD API endpoint for CPE searches
  # Documentation: https://nvd.nist.gov/developers/products
  cpe_uri = URI("https://services.nvd.nist.gov/rest/json/cpes/2.0")
  cpe_uri.query = URI.encode_www_form({
    cpeMatchString: @normalized_cpe
  })

  begin
    response = Net::HTTP.get_response(cpe_uri)

    expect(response.code).to eq('200'),
      "NVD API request failed with status #{response.code}"

    data = JSON.parse(response.body)
    total_results = data.dig('totalResults') || 0

    expect(total_results).to be > 0,
      "CPE '#{@normalized_cpe}' not found in NVD database (0 results)"

  rescue SocketError, Net::OpenTimeout, Net::ReadTimeout => e
    pending "Network error connecting to NVD API: #{e.message}"
  rescue JSON::ParserError => e
    pending "Failed to parse NVD API response: #{e.message}"
  end
end

When('I collect CPEs for well-known components:') do |table|
  @collected_cpes = []
  component_names = table.raw.flatten

  component_names.each do |name|
    component = SBOMLoader.find_component(@current_sbom, name)
    next if component.nil?

    cpe = component['cpe']
    next if cpe.nil? || cpe.empty?

    parsed = CPEValidator.parse(cpe)
    @collected_cpes << { name: name, cpe: cpe, parsed: parsed } if parsed
  end
end

When('I normalize all CPE vendors') do
  pending "No CPEs collected" if @collected_cpes.nil? || @collected_cpes.empty?

  @collected_cpes.each do |item|
    parsed = item[:parsed]
    product = parsed[:product]

    # Apply known vendor mappings
    correct_vendor = CPEValidator::KNOWN_VENDOR_MAPPINGS[product] || parsed[:vendor]
    parsed[:vendor] = correct_vendor
  end
end

When('I remove Nix suffixes from all CPE versions') do
  pending "No CPEs collected" if @collected_cpes.nil? || @collected_cpes.empty?

  @collected_cpes.each do |item|
    parsed = item[:parsed]
    version = parsed[:version]
    parsed[:version] = version.sub(/-[0-9]+$/, '')
  end
end

Then('at least {int}% of CPEs should exist in NVD database') do |min_percentage|
  pending "No CPEs collected" if @collected_cpes.nil? || @collected_cpes.empty?

  require 'net/http'
  require 'uri'
  require 'json'

  found_count = 0
  total_count = @collected_cpes.length

  begin
    @collected_cpes.each do |item|
      parsed = item[:parsed]
      # Reconstruct normalized CPE
      cpe_string = "cpe:2.3:#{parsed[:part]}:#{parsed[:vendor]}:#{parsed[:product]}:#{parsed[:version]}"

      # Query NVD API
      cpe_uri = URI("https://services.nvd.nist.gov/rest/json/cpes/2.0")
      cpe_uri.query = URI.encode_www_form({
        cpeMatchString: cpe_string
      })

      response = Net::HTTP.get_response(cpe_uri)
      next unless response.code == '200'

      data = JSON.parse(response.body)
      total_results = data.dig('totalResults') || 0

      found_count += 1 if total_results > 0

      # Rate limiting: NVD allows 5 requests per 30 seconds without API key
      sleep(6) if @collected_cpes.length > 1
    end

    percentage = (found_count.to_f / total_count * 100).round

    expect(percentage).to be >= min_percentage,
      "Only #{percentage}% (#{found_count}/#{total_count}) of CPEs found in NVD database, expected at least #{min_percentage}%"

  rescue SocketError, Net::OpenTimeout, Net::ReadTimeout => e
    pending "Network error connecting to NVD API: #{e.message}"
  rescue JSON::ParserError => e
    pending "Failed to parse NVD API response: #{e.message}"
  end
end

Given('the fixtures directory {string} exists') do |dir|
  @fixtures_dir = File.expand_path(dir, PROJECT_ROOT)
  expect(Dir.exist?(@fixtures_dir)).to be(true),
    "Fixtures directory not found: #{@fixtures_dir}"
end

When('I load the fixture file {string}') do |filename|
  require 'yaml'
  file_path = File.join(@fixtures_dir, filename)

  expect(File.exist?(file_path)).to be(true),
    "Fixture file not found: #{file_path}"

  @current_fixture = YAML.load_file(file_path)
end

Then('the mappings should include vendor for {string}') do |component_name|
  pending "No fixture loaded" if @current_fixture.nil?

  mappings = @current_fixture['vendor_mappings'] || {}
  expect(mappings.key?(component_name)).to be(true),
    "Fixture does not include vendor mapping for '#{component_name}'"
end

Then('the vendor for {string} should be {string}') do |component_name, expected_vendor|
  pending "No fixture loaded" if @current_fixture.nil?

  mappings = @current_fixture['vendor_mappings'] || {}
  actual_vendor = mappings[component_name]

  expect(actual_vendor).to eq(expected_vendor),
    "Expected vendor for '#{component_name}' to be '#{expected_vendor}', got '#{actual_vendor}'"
end
