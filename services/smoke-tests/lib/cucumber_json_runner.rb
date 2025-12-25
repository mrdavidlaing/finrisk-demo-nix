require 'json'
require 'open3'
require 'time'

class CucumberJsonRunner
  def self.run
    start_time = Time.now
    
    # Run cucumber with JSON formatter
    json_output, status = Open3.capture2(
      { 'API_GATEWAY_URL' => ENV['API_GATEWAY_URL'] || 'http://localhost:8080' },
      'bundle', 'exec', 'cucumber', 
      '--format', 'json', '--out', '/tmp/cucumber_results.json',
      '--format', 'pretty', '--no-strict'
    )
    
    duration = Time.now - start_time
    
    # Parse JSON results
    json_data = File.read('/tmp/cucumber_results.json') rescue '[]'
    cucumber_results = JSON.parse(json_data) rescue []
    
    # Transform to our format
    transform_results(cucumber_results, duration, status.success?)
  end

  private

  def self.transform_results(cucumber_results, duration, success)
    features = []
    total_scenarios = 0
    passed_scenarios = 0
    failed_scenarios = 0
    pending_scenarios = 0

    cucumber_results.each do |feature_data|
      feature = {
        name: feature_data['name'] || 'Unknown Feature',
        description: extract_description(feature_data),
        scenarios: []
      }

      feature_data['elements']&.each do |element|
        next unless element['type'] == 'scenario'

        scenario = {
          name: element['name'] || 'Unknown Scenario',
          status: determine_scenario_status(element),
          duration: calculate_duration(element),
          steps: []
        }

        element['steps']&.each do |step_data|
          step = {
            keyword: step_data['keyword']&.strip || 'Given',
            text: step_data['name'] || '',
            status: step_data['result']&.fetch('status', 'unknown') || 'unknown',
            duration: (step_data['result']&.fetch('duration', 0) || 0) / 1_000_000_000.0 # Convert nanoseconds to seconds
          }

          if step[:status] == 'failed'
            step[:error] = step_data['result']&.fetch('error_message', 'Unknown error')
          end

          scenario[:steps] << step
        end

        feature[:scenarios] << scenario
        total_scenarios += 1
        
        case scenario[:status]
        when 'passed'
          passed_scenarios += 1
        when 'failed'
          failed_scenarios += 1
        when 'pending', 'skipped'
          pending_scenarios += 1
        end
      end

      features << feature unless feature[:scenarios].empty?
    end

    {
      status: failed_scenarios == 0 && success ? 'passed' : 'failed',
      summary: {
        total: total_scenarios,
        passed: passed_scenarios,
        failed: failed_scenarios,
        pending: pending_scenarios
      },
      duration: duration.round(2),
      features: features
    }
  end

  def self.extract_description(feature_data)
    description = feature_data['description'] || ''
    # Extract the "As a... I want... So that..." part
    lines = description.split("\n").map(&:strip).reject(&:empty?)
    lines.join(' ')
  end

  def self.determine_scenario_status(element)
    return 'pending' unless element['steps']
    
    step_statuses = element['steps'].map { |s| s['result']&.fetch('status', 'unknown') }
    
    if step_statuses.include?('failed')
      'failed'
    elsif step_statuses.include?('pending') || step_statuses.include?('skipped')
      'pending'
    elsif step_statuses.all? { |s| s == 'passed' }
      'passed'
    else
      'unknown'
    end
  end

  def self.calculate_duration(element)
    return 0.0 unless element['steps']
    
    element['steps'].sum do |step|
      (step['result']&.fetch('duration', 0) || 0) / 1_000_000_000.0
    end.round(2)
  end
end

