When('I examine all files matching {string}') do |pattern|
  full_pattern = File.expand_path(pattern, PROJECT_ROOT)
  @examined_files = Dir.glob(full_pattern).sort
  expect(@examined_files).not_to be_empty, "No files found matching: #{pattern}"
end

Then('each SBOM should have a compositions section') do
  @examined_files.each do |file_path|
    sbom = SBOMLoader.load(file_path)
    compositions = sbom['compositions']

    expect(compositions).not_to be_nil,
      "#{File.basename(file_path)} has no compositions section"
    expect(compositions).to be_an(Array),
      "#{File.basename(file_path)} compositions is not an array"
    expect(compositions).not_to be_empty,
      "#{File.basename(file_path)} compositions array is empty"
  end
end

Then('the compositions should reference exactly {int} assemblies') do |expected_count|
  compositions = @current_sbom['compositions'] || []

  total_assemblies = compositions.sum do |composition|
    (composition['assemblies'] || []).length
  end

  expect(total_assemblies).to eq(expected_count),
    "Expected exactly #{expected_count} assemblies, but found #{total_assemblies}"
end

Then('the assemblies should include {string}') do |expected_ref|
  compositions = @current_sbom['compositions'] || []

  # Assemblies are strings (bom-refs), not objects with 'ref' field
  all_assembly_refs = compositions.flat_map do |composition|
    composition['assemblies'] || []
  end.compact

  expect(all_assembly_refs.include?(expected_ref)).to be(true),
    "Expected assembly reference to '#{expected_ref}', but found: #{all_assembly_refs.join(', ')}"
end

Then('all assembly refs should end with {string}') do |expected_suffix|
  compositions = @current_sbom['compositions'] || []

  # Assemblies are strings (bom-refs), not objects with 'ref' field
  all_assembly_refs = compositions.flat_map do |composition|
    composition['assemblies'] || []
  end.compact

  invalid_refs = all_assembly_refs.reject { |ref| ref.end_with?(expected_suffix) }

  expect(invalid_refs).to be_empty,
    "Found assembly refs not ending with '#{expected_suffix}': #{invalid_refs.join(', ')}"
end

Then('the compositions should have at least {int} entry') do |min_count|
  compositions = @current_sbom['compositions'] || []
  expect(compositions.length).to be >= min_count,
    "Expected at least #{min_count} composition entries, found #{compositions.length}"
end

Then('each composition should have a bom-ref') do
  compositions = @current_sbom['compositions'] || []

  missing_ref = compositions.select { |c| c['bom-ref'].nil? || c['bom-ref'].empty? }

  expect(missing_ref).to be_empty,
    "Found #{missing_ref.length} compositions without bom-ref"
end

Then('each composition should have assemblies array') do
  compositions = @current_sbom['compositions'] || []

  missing_assemblies = compositions.select do |c|
    c['assemblies'].nil? || !c['assemblies'].is_a?(Array)
  end

  expect(missing_assemblies).to be_empty,
    "Found #{missing_assemblies.length} compositions without assemblies array"
end

Then('all assembly refs should match pattern {string}') do |pattern|
  regex = Regexp.new(pattern)

  # Extract assembly values (they're strings, not objects with 'ref' field)
  compositions = @current_sbom['compositions'] || []
  all_assembly_refs = compositions.flat_map do |composition|
    composition['assemblies'] || []
  end.compact

  non_matching = all_assembly_refs.reject { |ref| regex.match?(ref) }

  expect(non_matching).to be_empty,
    "Found assembly refs not matching pattern '#{pattern}':\n" +
    non_matching.first(10).map { |ref| "  #{ref}" }.join("\n")
end

Then('the first composition should NOT have a bom-ref field') do
  compositions = @current_sbom['compositions'] || []
  expect(compositions).not_to be_empty, "No compositions found"

  first_composition = compositions.first
  expect(first_composition.key?('bom-ref')).to be(false),
    "First composition has bom-ref: #{first_composition['bom-ref']}"
end

When('I extract all assembly refs from compositions') do
  compositions = @current_sbom['compositions'] || []

  # Assemblies are strings (Nix paths), not objects with 'ref' field
  @assembly_refs = compositions.flat_map do |composition|
    composition['assemblies'] || []
  end.compact.uniq
end

Then('each referenced SBOM file should exist in {string}') do |directory|
  sbom_dir = File.expand_path(directory, PROJECT_ROOT)

  missing_files = @assembly_refs.select do |ref|
    file_path = File.join(sbom_dir, ref)
    !File.exist?(file_path)
  end

  expect(missing_files).to be_empty,
    "Referenced SBOM files not found:\n" + missing_files.map { |f| "  #{f}" }.join("\n")
end
