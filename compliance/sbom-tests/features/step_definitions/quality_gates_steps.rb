Then('no component names should match pattern {string}') do |pattern|
  regex = Regexp.new(pattern)
  matching_components = []

  @examined_files.each do |file_path|
    sbom = SBOMLoader.load(file_path)
    components = SBOMLoader.components(sbom)

    components.each do |component|
      name = component['name']
      if name && regex.match?(name)
        matching_components << {
          sbom: File.basename(file_path),
          component: name
        }
      end
    end
  end

  expect(matching_components).to be_empty,
    "Found #{matching_components.length} components matching pattern '#{pattern}':\n" +
    matching_components.first(10).map { |m| "  #{m[:sbom]}: #{m[:component]}" }.join("\n")
end

When('I count components matching pattern {string}') do |pattern|
  regex = Regexp.new(pattern)
  components = SBOMLoader.components(@current_sbom)

  @component_count = components.count do |component|
    name = component['name']
    name && regex.match?(name)
  end
end

Then('the count should be greater than {int}') do |expected_min|
  expect(@component_count).to be > expected_min,
    "Expected count to be greater than #{expected_min}, but got #{@component_count}"
end

Then('the count should be greater than or equal to {int}') do |expected_min|
  expect(@component_count).to be >= expected_min,
    "Expected count to be greater than or equal to #{expected_min}, but got #{@component_count}"
end

Then('all component types should be one of:') do |table|
  valid_types = table.raw.flatten
  invalid_components = []

  @examined_files.each do |file_path|
    sbom = SBOMLoader.load(file_path)
    components = SBOMLoader.components(sbom)

    components.each do |component|
      type = component['type']
      unless valid_types.include?(type)
        invalid_components << {
          sbom: File.basename(file_path),
          component: component['name'],
          type: type
        }
      end
    end
  end

  expect(invalid_components).to be_empty,
    "Found components with invalid types:\n" +
    invalid_components.first(10).map { |c| "  #{c[:sbom]}: #{c[:component]} (#{c[:type]})" }.join("\n")
end

Then('all components should have a {string} field') do |field_name|
  missing_field = []

  @examined_files.each do |file_path|
    sbom = SBOMLoader.load(file_path)
    components = SBOMLoader.components(sbom)

    components.each do |component|
      if component[field_name].nil? || component[field_name].to_s.empty?
        missing_field << {
          sbom: File.basename(file_path),
          component: component['bom-ref'] || 'unknown'
        }
      end
    end
  end

  expect(missing_field).to be_empty,
    "Found #{missing_field.length} components missing '#{field_name}' field:\n" +
    missing_field.first(10).map { |m| "  #{m[:sbom]}: #{m[:component]}" }.join("\n")
end

When('I count all components') do
  components = SBOMLoader.components(@current_sbom)
  @component_count = components.length
end

When('I count all components as {string}') do |variable_name|
  components = SBOMLoader.components(@current_sbom)
  @counts ||= {}
  @counts[variable_name] = components.length
end

Then('{string} should be greater than or equal to the sum of {string} and {string} and {string}') do |result_var, var1, var2, var3|
  @counts ||= {}

  result = @counts[result_var] || 0
  sum = (@counts[var1] || 0) + (@counts[var2] || 0) + (@counts[var3] || 0)

  expect(result).to be >= sum,
    "Expected #{result_var} (#{result}) to be >= sum of #{var1} (#{@counts[var1]}), " +
    "#{var2} (#{@counts[var2]}), and #{var3} (#{@counts[var3]}) = #{sum}"
end
