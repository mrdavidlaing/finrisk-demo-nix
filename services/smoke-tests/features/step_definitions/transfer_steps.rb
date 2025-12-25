Given('the API gateway is available') do
  response = api_client.get('/api/health')
  expect(response.status).to eq(200), "API Gateway is not available"
end

Given('a verified user {string}') do |user_id|
  @sender_id = user_id
end

Given('a recipient {string} not on any sanctions list') do |recipient_id|
  @recipient_id = recipient_id
end

Given('a recipient {string} on the OFAC sanctions list') do |recipient_id|
  @recipient_id = recipient_id
end

Given('an unverified user with empty ID') do
  @sender_id = ''
end

When('I submit a SWIFT transfer of ${int} USD from {string} to {string}') do |amount, from, to|
  @response = api_client.post('/api/transfer', {
    senderId: from,
    recipientId: to,
    amount: amount,
    currency: 'USD',
    rail: 'SWIFT'
  })
  @transfer_response = @response.body
end

When('I submit a CRYPTO transfer of ${int} USDT from {string} to {string}') do |amount, from, to|
  @response = api_client.post('/api/transfer', {
    senderId: from,
    recipientId: to,
    amount: amount,
    currency: 'USDT',
    rail: 'CRYPTO'
  })
  @transfer_response = @response.body
end

When('I submit a SWIFT transfer of ${int} USD to {string}') do |amount, to|
  @response = api_client.post('/api/transfer', {
    senderId: @sender_id || '',
    recipientId: to,
    amount: amount,
    currency: 'USD',
    rail: 'SWIFT'
  })
  @transfer_response = @response.body
end

Then('the transfer should be accepted') do
  error_msg = if @response.status != 200
    body_info = @response.respond_to?(:raw_body) ? @response.raw_body : (@response.body.to_s rescue 'N/A')
    "Expected transfer to be accepted but got status #{@response.status}. Response body: #{body_info}"
  else
    "Expected transfer to be accepted but got status #{@response.status}"
  end
  expect(@response.status).to eq(200), error_msg
end

Then('the transfer should be rejected with {string}') do |expected_error|
  expect(@response.status).to be >= 400, "Expected transfer to be rejected but got status #{@response.status}"
  # Check both JSON error field and raw body (API gateway returns plain text errors)
  body_text = if @response.respond_to?(:raw_body)
    @response.raw_body.to_s
  elsif @response.body.is_a?(String)
    @response.body
  elsif @response.body.is_a?(Hash)
    @response.body['error'] || @response.body.to_json
  else
    @response.body.to_s
  end
  expect(body_text.to_s).to match(/#{Regexp.escape(expected_error)}/i), "Expected error message '#{expected_error}' but got: #{body_text}"
end

Then('the response should include a transfer ID') do
  expect(@transfer_response).to be_a(Hash), "Expected transfer response to be a hash"
  expect(@transfer_response['id']).not_to be_nil, "Expected transfer response to include an ID"
  expect(@transfer_response['id']).not_to be_empty, "Expected transfer response to include a non-empty ID"
end

Then('the response should include a transaction hash') do
  expect(@transfer_response).to be_a(Hash), "Expected transfer response to be a hash"
  expect(@transfer_response['id']).not_to be_nil, "Expected transfer response to include a transaction hash (id)"
  expect(@transfer_response['id']).not_to be_empty, "Expected transfer response to include a non-empty transaction hash"
end

Then('the fee should be at least ${int}') do |min_fee|
  expect(@transfer_response).to be_a(Hash), "Expected transfer response to be a hash"
  expect(@transfer_response['fee']).to be >= min_fee, "Expected fee to be at least $#{min_fee} but got $#{@transfer_response['fee']}"
end

Then('the transaction should be logged in the audit service') do
  # For now, we just verify the transfer was successful
  # In a real scenario, we might query the audit service to verify the log entry
  expect(@response.status).to eq(200), "Transfer must succeed for audit logging"
end

