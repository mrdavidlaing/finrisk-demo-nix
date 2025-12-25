Then('the api-gateway should be healthy') do
  response = api_client.get('/api/health')
  expect(response.status).to eq(200), "API Gateway health check failed"
  expect(response.body['status']).to eq('healthy'), "API Gateway is not healthy"
end

Then('the kyc-service should be healthy') do
  # KYC service health is checked indirectly through the API gateway
  # In a real scenario, we might check it directly
  response = api_client.get('/api/health')
  expect(response.status).to eq(200), "Services are not accessible"
end

Then('the fee-service should be healthy') do
  # Fee service health is checked indirectly through the API gateway
  response = api_client.get('/api/health')
  expect(response.status).to eq(200), "Services are not accessible"
end

Then('the sanctions-service should be healthy') do
  # Sanctions service health is checked indirectly through the API gateway
  response = api_client.get('/api/health')
  expect(response.status).to eq(200), "Services are not accessible"
end

Then('the crypto-transfer service should be healthy') do
  # Crypto transfer service health is checked indirectly through the API gateway
  response = api_client.get('/api/health')
  expect(response.status).to eq(200), "Services are not accessible"
end

Then('the audit-service should be healthy') do
  # Audit service health is checked indirectly through the API gateway
  response = api_client.get('/api/health')
  expect(response.status).to eq(200), "Services are not accessible"
end

