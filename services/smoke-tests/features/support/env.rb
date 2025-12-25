require 'faraday'
require 'json'
require 'rspec/expectations'

API_GATEWAY_URL = ENV['API_GATEWAY_URL'] || 'http://localhost:8080'

# API Client helper
class ApiClient
  def initialize(base_url)
    @conn = Faraday.new(url: base_url) do |f|
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
    end
  end

  def get(path)
    response = @conn.get(path)
    OpenStruct.new(
      status: response.status,
      body: response.body || {},
      headers: response.headers
    )
  end

  def post(path, data)
    response = @conn.post(path, data)
    OpenStruct.new(
      status: response.status,
      body: response.body || {},
      headers: response.headers
    )
  rescue Faraday::Error => e
    OpenStruct.new(
      status: 500,
      body: { error: e.message },
      headers: {}
    )
  end
end

# World object to share state between steps
World do
  @api_client = ApiClient.new(API_GATEWAY_URL)
  @response = nil
  @transfer_response = nil
end

def api_client
  @api_client
end

