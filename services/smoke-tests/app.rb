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
  begin
    CucumberJsonRunner.run.to_json
  rescue => e
    status 500
    {
      status: 'error',
      error: e.message,
      backtrace: e.backtrace.first(5)
    }.to_json
  end
end

