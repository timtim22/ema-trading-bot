require 'rails_helper'

RSpec.describe TradingBotService, '#check_market_hours', type: :service do
  describe 'Ticket T6: Unit Test Market-Hours Guard' do
    let(:symbol) { 'AAPL' }
    let(:service) { described_class.new(symbol) }
    
    # Helper method to create time in ET timezone with proper offset
    def et_time(date_string, time_string)
      # Use proper EST offset for January dates (-05:00)
      Time.parse("#{date_string} #{time_string} -0500")
    end
    
    describe 'acceptance criteria validation' do
      context 'when Time=Sunday 12:00 ET' do
        it 'returns non-nil error' do
          # Find a Sunday and set time to 12:00 PM ET
          sunday_time = et_time('2024-01-07', '12:00:00') # January 7, 2024 is a Sunday
          
          Timecop.freeze(sunday_time) do
            result = service.check_market_hours
            
            # Core acceptance criteria: should return non-nil error on Sunday
            expect(result).not_to be_nil
            expect(result).to be_a(String)
            expect(result).to include('weekend')
          end
        end
      end
      
      context 'when Time=Wednesday 10:00 ET' do
        it 'returns nil' do
          # Find a Wednesday and set time to 10:00 AM ET (during market hours)
          wednesday_time = et_time('2024-01-10', '10:00:00') # January 10, 2024 is a Wednesday
          
          Timecop.freeze(wednesday_time) do
            result = service.check_market_hours
            
            # Core acceptance criteria: should return nil during market hours
            expect(result).to be_nil
          end
        end
      end
    end
    
    describe 'comprehensive market hours testing' do
      context 'weekend scenarios' do
        it 'returns error on Saturday' do
          saturday_time = et_time('2024-01-06', '15:00:00') # January 6, 2024 is a Saturday
          
          Timecop.freeze(saturday_time) do
            result = service.check_market_hours
            
            expect(result).to eq('Outside market hours: weekend')
          end
        end
        
        it 'returns error on Sunday morning' do
          sunday_morning = et_time('2024-01-07', '08:00:00')
          
          Timecop.freeze(sunday_morning) do
            result = service.check_market_hours
            
            expect(result).to eq('Outside market hours: weekend')
          end
        end
        
        it 'returns error on Sunday evening' do
          sunday_evening = et_time('2024-01-07', '20:00:00')
          
          Timecop.freeze(sunday_evening) do
            result = service.check_market_hours
            
            expect(result).to eq('Outside market hours: weekend')
          end
        end
      end
      
      context 'weekday before market hours' do
        it 'returns error at 9:00 AM ET (before 9:30 AM open)' do
          monday_early = et_time('2024-01-08', '09:00:00') # January 8, 2024 is a Monday
          
          Timecop.freeze(monday_early) do
            result = service.check_market_hours
            
            expect(result).to eq('Outside market hours: before market open (9:30 AM ET)')
          end
        end
        
        it 'returns error at 9:29 AM ET (1 minute before open)' do
          tuesday_almost_open = et_time('2024-01-09', '09:29:00')
          
          Timecop.freeze(tuesday_almost_open) do
            result = service.check_market_hours
            
            expect(result).to eq('Outside market hours: before market open (9:30 AM ET)')
          end
        end
        
        it 'returns error at 6:00 AM ET (very early)' do
          wednesday_very_early = et_time('2024-01-10', '06:00:00')
          
          Timecop.freeze(wednesday_very_early) do
            result = service.check_market_hours
            
            expect(result).to eq('Outside market hours: before market open (9:30 AM ET)')
          end
        end
      end
      
      context 'during market hours' do
        it 'returns nil at 9:30 AM ET (market open)' do
          thursday_open = et_time('2024-01-11', '09:30:00')
          
          Timecop.freeze(thursday_open) do
            result = service.check_market_hours
            
            expect(result).to be_nil
          end
        end
        
        it 'returns nil at 12:00 PM ET (midday)' do
          friday_midday = et_time('2024-01-12', '12:00:00')
          
          Timecop.freeze(friday_midday) do
            result = service.check_market_hours
            
            expect(result).to be_nil
          end
        end
        
        it 'returns nil at 3:59 PM ET (1 minute before close)' do
          monday_almost_close = et_time('2024-01-08', '15:59:00')
          
          Timecop.freeze(monday_almost_close) do
            result = service.check_market_hours
            
            expect(result).to be_nil
          end
        end
        
        it 'returns nil at 4:00 PM ET (market close boundary)' do
          tuesday_close = et_time('2024-01-09', '16:00:00')
          
          Timecop.freeze(tuesday_close) do
            result = service.check_market_hours
            
            expect(result).to be_nil
          end
        end
      end
      
      context 'weekday after market hours' do
        it 'returns error at 4:01 PM ET (1 minute after close)' do
          wednesday_after_close = et_time('2024-01-10', '16:01:00')
          
          Timecop.freeze(wednesday_after_close) do
            result = service.check_market_hours
            
            expect(result).to eq('Outside market hours: after market close (4:00 PM ET)')
          end
        end
        
        it 'returns error at 6:00 PM ET (evening)' do
          thursday_evening = et_time('2024-01-11', '18:00:00')
          
          Timecop.freeze(thursday_evening) do
            result = service.check_market_hours
            
            expect(result).to eq('Outside market hours: after market close (4:00 PM ET)')
          end
        end
        
        it 'returns error at 11:00 PM ET (late night)' do
          friday_late = et_time('2024-01-12', '23:00:00')
          
          Timecop.freeze(friday_late) do
            result = service.check_market_hours
            
            expect(result).to eq('Outside market hours: after market close (4:00 PM ET)')
          end
        end
      end
    end
    
    describe 'timezone handling' do
      it 'correctly handles different timezones by converting to ET' do
        # Test with a time that would be different in other zones
        # 10:00 AM PT = 1:00 PM ET (during market hours)
        
        # Create a Pacific time that translates to market hours in ET
        pacific_time = Time.parse("2024-01-10 10:00:00 -0800") # 10 AM PST = 1 PM EST
        
        Timecop.freeze(pacific_time) do
          result = service.check_market_hours
          
          # Should be nil because it's 1:00 PM ET (during market hours)
          expect(result).to be_nil
        end
      end
      
      it 'correctly identifies weekend in different timezones' do
        # Sunday morning in Pacific should still be weekend in ET
        pacific_sunday = Time.parse("2024-01-07 09:00:00 -0800")
        
        Timecop.freeze(pacific_sunday) do
          result = service.check_market_hours
          
          # Should still be weekend error
          expect(result).to eq('Outside market hours: weekend')
        end
      end
    end
    
    describe 'edge cases and boundary conditions' do
      it 'handles midnight transitions correctly' do
        # Test Sunday midnight to Monday morning transition
        sunday_midnight = et_time('2024-01-07', '23:59:59')
        monday_midnight = et_time('2024-01-08', '00:00:01')
        
        Timecop.freeze(sunday_midnight) do
          result = service.check_market_hours
          expect(result).to eq('Outside market hours: weekend')
        end
        
        Timecop.freeze(monday_midnight) do
          result = service.check_market_hours
          expect(result).to eq('Outside market hours: before market open (9:30 AM ET)')
        end
      end
      
      it 'handles Friday evening to Saturday transition' do
        friday_late = et_time('2024-01-12', '23:59:59')
        saturday_early = et_time('2024-01-13', '00:00:01')
        
        Timecop.freeze(friday_late) do
          result = service.check_market_hours
          expect(result).to eq('Outside market hours: after market close (4:00 PM ET)')
        end
        
        Timecop.freeze(saturday_early) do
          result = service.check_market_hours
          expect(result).to eq('Outside market hours: weekend')
        end
      end
      
      it 'handles all weekdays during market hours' do
        # Test each weekday (Monday through Friday) during market hours
        weekdays = [
          ['2024-01-08', 'Monday'],    # January 8, 2024
          ['2024-01-09', 'Tuesday'],   # January 9, 2024
          ['2024-01-10', 'Wednesday'], # January 10, 2024
          ['2024-01-11', 'Thursday'],  # January 11, 2024
          ['2024-01-12', 'Friday']     # January 12, 2024
        ]
        
        weekdays.each do |date, day_name|
          market_time = et_time(date, '14:00:00') # 2:00 PM ET
          
          Timecop.freeze(market_time) do
            result = service.check_market_hours
            expect(result).to be_nil, "Expected nil for #{day_name} at 2:00 PM ET"
          end
        end
      end
    end
    
    describe 'integration with fetch_market_data' do
      let(:alpaca_service) { instance_double(AlpacaDataService) }
      
      before do
        service.instance_variable_set(:@alpaca_service, alpaca_service)
      end
      
      context 'when market is closed and data fetch fails' do
        it 'sets last_error to market hours message instead of generic error' do
          sunday_time = et_time('2024-01-07', '12:00:00')
          
          Timecop.freeze(sunday_time) do
            # Simulate data fetch failure
            allow(alpaca_service).to receive(:fetch_closes_with_timestamp).and_return(nil)
            allow(alpaca_service).to receive(:last_error).and_return('API Error')
            
            result = service.fetch_market_data
            
            expect(result).to be_nil
            expect(service.last_error).to eq('Outside market hours: weekend')
          end
        end
      end
    end
  end
end 