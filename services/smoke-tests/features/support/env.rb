require 'faraday'
require 'json'
require 'ostruct'
require 'rspec/expectations'

API_GATEWAY_URL = ENV['API_GATEWAY_URL'] || 'http://localhost:8080'

# API Client helper
class ApiClient
  def initialize(base_url)
    @base_url = base_url
  end

  def get(path)
    make_request(:get, path, nil)
  end

  def post(path, data)
    make_request(:post, path, data)
  end

  private

  def make_request(method, path, data)
    conn = Faraday.new(url: @base_url) do |f|
      f.request :json
      f.adapter Faraday.default_adapter
    end

    response = if method == :get
      conn.get(path)
    else
      conn.post(path, data)
    end

    # Try to parse as JSON, fallback to plain text
    parsed_body = begin
      JSON.parse(response.body)
    rescue JSON::ParserError, TypeError
      response.body
    end

    raw_body = response.body.to_s

    OpenStruct.new(
      status: response.status,
      body: parsed_body.is_a?(Hash) ? parsed_body : (parsed_body.is_a?(String) ? {} : parsed_body),
      raw_body: raw_body,
      headers: response.headers
    )
  rescue Faraday::Error => e
    OpenStruct.new(
      status: 500,
      body: { error: e.message },
      raw_body: e.message,
      headers: {}
    )
  end
end

# World object to share state between steps
World do
  # #region agent log
  log_path = ENV['DEBUG_LOG_PATH'] || '/home/mrdavidlaing/Work/finrisk-demo-nix/.cursor/debug.log'
  File.open(log_path, 'a') { |f| f.puts(JSON.generate({id:"log_#{Time.now.to_f}_#{rand(1000)}",timestamp:(Time.now.to_f*1000).to_i,sessionId:"debug-session",runId:(ENV['DEBUG_RUN_ID'] || 'pre-fix'),hypothesisId:"H2",location:"env.rb:World:init",message:"World block initializing",data:{api_gateway_url:API_GATEWAY_URL}})) } rescue nil
  # #endregion
  @api_client = ApiClient.new(API_GATEWAY_URL)
  @response = nil
  @transfer_response = nil
  self  # Return self to satisfy Cucumber's World requirement
end

def api_client
  @api_client
end

# Preflight readiness check - wait for services to be available
Before do
  max_attempts = 30
  attempt = 0
  wait_interval = 1.0 # seconds
  
  # Wait for API gateway to be ready
  api_gateway_ready = false
  while attempt < max_attempts && !api_gateway_ready
    begin
      response = api_client.get('/api/health')
      if response.status == 200
        api_gateway_ready = true
      end
    rescue => e
      # Service not ready yet
    end
    
    unless api_gateway_ready
      attempt += 1
      sleep(wait_interval) if attempt < max_attempts
    end
  end
  
  unless api_gateway_ready
    raise "API Gateway did not become ready within #{max_attempts * wait_interval} seconds"
  end
end

