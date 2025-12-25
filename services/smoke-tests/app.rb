require 'sinatra'
require 'json'
require_relative 'lib/cucumber_json_runner'

set :port, 8090
set :bind, '0.0.0.0'

get '/health' do
  content_type :json
  { status: 'healthy', service: 'smoke-tests' }.to_json
end

get '/run-tests' do
  content_type :json
  # #region agent log
  CucumberJsonRunner._agent_log(
    hypothesis_id: 'H1',
    location: 'app.rb:run-tests:entry',
    message: 'Received /run-tests request',
    data: { pwd: Dir.pwd, api_gateway_url: (ENV['API_GATEWAY_URL'] || 'unset') }
  )
  # #endregion agent log
  begin
    CucumberJsonRunner.run.to_json
  rescue => e
    status 500
    # #region agent log
    CucumberJsonRunner._agent_log(
      hypothesis_id: 'H1',
      location: 'app.rb:run-tests:rescue',
      message: 'Exception running cucumber',
      data: { error_class: e.class.to_s, error: e.message.to_s[0, 800] }
    )
    # #endregion agent log
    {
      status: 'error',
      error: e.message,
      backtrace: e.backtrace.first(5)
    }.to_json
  end
end

