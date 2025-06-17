require 'rails_helper'

RSpec.describe AlpacaDataService, type: :service do
  describe 'Ticket T5: Unit Test Data Fetching Success & Failure' do
    let(:api_key_id) { 'test_api_key_id' }
    let(:api_secret_key) { 'test_api_secret_key' }
    let(:service) { described_class.new(api_key_id, api_secret_key) }
    let(:symbol) { 'AAPL' }
    let(:base_url) { 'https://data.alpaca.markets/v2' }
    
    before do
      # Mock environment variables to avoid needing actual credentials
      allow(ENV).to receive(:fetch).with("ALPACA_API_KEY_ID").and_return(api_key_id)
      allow(ENV).to receive(:fetch).with("ALPACA_API_SECRET_KEY").and_return(api_secret_key)
      allow(ENV).to receive(:fetch).with("POLL_TIMEFRAME").and_return("5Min")
      allow(ENV).to receive(:fetch).with("POLL_LIMIT").and_return("50")
    end
    
    describe '#fetch_bars' do
      context 'on successful API response' do
        let(:successful_response_body) do
          {
            "bars" => [
              {
                "t" => "2023-05-27T09:30:00Z",
                "o" => 180.50,
                "h" => 181.20,
                "l" => 180.30,
                "c" => 181.00,
                "v" => 50000
              },
              {
                "t" => "2023-05-27T09:35:00Z", 
                "o" => 181.00,
                "h" => 181.75,
                "l" => 180.85,
                "c" => 181.60,
                "v" => 45000
              }
            ],
            "symbol" => symbol,
            "next_page_token" => nil
          }
        end
        
        before do
          # Stub with the exact query parameters that AlpacaDataService uses by default
          stub_request(:get, "#{base_url}/stocks/#{symbol}/bars")
            .with(
              query: {
                "timeframe" => "5Min",
                "limit" => "50",
                "end" => "2025-05-28T16:00:00Z",
                "start" => "2025-05-27T09:30:00Z"
              },
              headers: {
                'APCA-API-KEY-ID' => api_key_id,
                'APCA-API-SECRET-KEY' => api_secret_key
              }
            )
            .to_return(
              status: 200,
              body: successful_response_body.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )
        end
        
        it 'returns parsed hash on valid response' do
          result = service.fetch_bars(symbol)
          
          # Core acceptance criteria: should return parsed hash
          expect(result).to be_a(Hash)
          expect(result).to eq(successful_response_body)
          
          # Verify the structure matches expected API response
          expect(result['bars']).to be_an(Array)
          expect(result['bars'].length).to eq(2)
          expect(result['symbol']).to eq(symbol)
          
          # Verify individual bar data structure
          first_bar = result['bars'].first
          expect(first_bar['t']).to eq('2023-05-27T09:30:00Z')
          expect(first_bar['c']).to eq(181.00)
          expect(first_bar['o']).to eq(180.50)
          expect(first_bar['h']).to eq(181.20)
          expect(first_bar['l']).to eq(180.30)
          expect(first_bar['v']).to eq(50000)
        end
        
        it 'stores the last response for inspection' do
          service.fetch_bars(symbol)
          
          expect(service.last_response).to be_present
          expect(service.last_response.status).to eq(200)
        end
        
        it 'does not set an error on successful request' do
          result = service.fetch_bars(symbol)
          
          # On successful request, no new error should be set
          expect(result).not_to be_nil
          expect(service.last_error).to be_nil
        end
      end
      
      context 'on HTTP 500 server error' do
        let(:error_response_body) { 'Internal Server Error' }
        
        before do
          # Stub with the exact query parameters that AlpacaDataService uses by default
          stub_request(:get, "#{base_url}/stocks/#{symbol}/bars")
            .with(
              query: {
                "timeframe" => "5Min",
                "limit" => "50",
                "end" => "2025-05-28T16:00:00Z",
                "start" => "2025-05-27T09:30:00Z"
              },
              headers: {
                'APCA-API-KEY-ID' => api_key_id,
                'APCA-API-SECRET-KEY' => api_secret_key
              }
            )
            .to_return(
              status: 500,
              body: error_response_body,
              headers: { 'Content-Type' => 'text/plain' }
            )
        end
        
        it 'returns nil on 500 error' do
          result = service.fetch_bars(symbol)
          
          # Core acceptance criteria: should return nil on 500
          expect(result).to be_nil
        end
        
        it 'sets last_error containing status code on 500 error' do
          service.fetch_bars(symbol)
          
          # Core acceptance criteria: should set last_error with status code
          expect(service.last_error).to be_present
          expect(service.last_error).to include('500')
          expect(service.last_error).to include('Alpaca Data Error')
          expect(service.last_error).to include(error_response_body)
          
          # Verify exact format
          expected_error = "Alpaca Data Error (500): #{error_response_body}"
          expect(service.last_error).to eq(expected_error)
        end
        
        it 'stores the error response for inspection' do
          service.fetch_bars(symbol)
          
          expect(service.last_response).to be_present
          expect(service.last_response.status).to eq(500)
          expect(service.last_response.body).to eq(error_response_body)
        end
      end
      
      context 'with different HTTP error codes' do
        [400, 401, 403, 404, 429, 502, 503].each do |status_code|
          it "returns nil and sets error for HTTP #{status_code}" do
            # Use default query parameters
            stub_request(:get, "#{base_url}/stocks/#{symbol}/bars")
              .with(query: hash_including({
                "timeframe" => "5Min",
                "limit" => "50"
              }))
              .to_return(status: status_code, body: "Error #{status_code}")
            
            result = service.fetch_bars(symbol)
            
            expect(result).to be_nil
            expect(service.last_error).to include(status_code.to_s)
          end
        end
      end
      
      context 'with custom parameters' do
        it 'passes custom parameters correctly' do
          stub_request(:get, "#{base_url}/stocks/#{symbol}/bars")
            .with(
              query: {
                timeframe: '1Min',
                limit: 100,
                start: '2023-05-27T09:30:00Z',
                end: '2023-05-27T16:00:00Z'
              }
            )
            .to_return(status: 200, body: { bars: [] }.to_json)
          
          service.fetch_bars(
            symbol,
            timeframe: '1Min',
            limit: 100,
            from: '2023-05-27T09:30:00Z',
            to: '2023-05-27T16:00:00Z'
          )
          
          # Verify the request was made with correct parameters
          expect(WebMock).to have_requested(:get, "#{base_url}/stocks/#{symbol}/bars")
            .with(query: hash_including({
              'timeframe' => '1Min',
              'limit' => '100',
              'start' => '2023-05-27T09:30:00Z',
              'end' => '2023-05-27T16:00:00Z'
            }))
        end
      end
      
      context 'with malformed JSON response' do
        before do
          stub_request(:get, "#{base_url}/stocks/#{symbol}/bars")
            .with(query: hash_including({
              "timeframe" => "5Min",
              "limit" => "50"
            }))
            .to_return(status: 200, body: 'invalid json{')
        end
        
        it 'handles JSON parsing errors gracefully' do
          expect { service.fetch_bars(symbol) }.to raise_error(JSON::ParserError)
        end
      end
      
      context 'integration with real request structure' do
        it 'sends correct headers and URL structure' do
          stub_request(:get, "#{base_url}/stocks/#{symbol}/bars")
            .with(query: hash_including({
              "timeframe" => "5Min",
              "limit" => "50"
            }))
            .to_return(status: 200, body: { bars: [] }.to_json)
          
          service.fetch_bars(symbol)
          
          # Verify the request was made with correct URL and basic query parameters
          expect(WebMock).to have_requested(:get, "#{base_url}/stocks/#{symbol}/bars")
            .with(query: hash_including({
              "timeframe" => "5Min",
              "limit" => "50"
            }))
        end
        
        it 'handles rate limit headers when present' do
          stub_request(:get, "#{base_url}/stocks/#{symbol}/bars")
            .with(query: hash_including({
              "timeframe" => "5Min",
              "limit" => "50"
            }))
            .to_return(
              status: 200, 
              body: { bars: [] }.to_json,
              headers: {
                'x-ratelimit-remaining' => '95',
                'x-ratelimit-limit' => '100',
                'x-ratelimit-reset' => '1234567890'
              }
            )
          
          service.fetch_bars(symbol)
          
          rate_info = service.rate_limit_info
          expect(rate_info[:remaining]).to eq('95')
          expect(rate_info[:limit]).to eq('100')
          expect(rate_info[:reset]).to eq('1234567890')
        end
      end
    end
  end
end 