require 'rails_helper'

RSpec.describe 'Ticket T13: Unit Test Polling Interval Configuration', type: :unit do
  describe FetchAndProcessJob do
    describe '.cron_schedule_for_interval' do
      it 'generates */1 * * * * for 1Min interval' do
        expect(FetchAndProcessJob.cron_schedule_for_interval("1Min")).to eq("*/1 * * * *")
      end

      it 'generates */1 * * * * for 1m interval' do
        expect(FetchAndProcessJob.cron_schedule_for_interval("1m")).to eq("*/1 * * * *")
      end

      it 'generates */5 * * * * for 5Min interval' do
        expect(FetchAndProcessJob.cron_schedule_for_interval("5Min")).to eq("*/5 * * * *")
      end

      it 'generates */5 * * * * for 5m interval' do
        expect(FetchAndProcessJob.cron_schedule_for_interval("5m")).to eq("*/5 * * * *")
      end

      it 'generates */15 * * * * for 15Min interval' do
        expect(FetchAndProcessJob.cron_schedule_for_interval("15Min")).to eq("*/15 * * * *")
      end

      it 'generates */30 * * * * for 30Min interval' do
        expect(FetchAndProcessJob.cron_schedule_for_interval("30Min")).to eq("*/30 * * * *")
      end

      it 'generates 0 * * * * for 1Hour interval' do
        expect(FetchAndProcessJob.cron_schedule_for_interval("1Hour")).to eq("0 * * * *")
      end

      it 'generates default */5 * * * * for unknown interval' do
        expect(FetchAndProcessJob.cron_schedule_for_interval("unknown")).to eq("*/5 * * * *")
      end

      it 'is case insensitive' do
        expect(FetchAndProcessJob.cron_schedule_for_interval("1MIN")).to eq("*/1 * * * *")
        expect(FetchAndProcessJob.cron_schedule_for_interval("5min")).to eq("*/5 * * * *")
      end
    end

    describe '.current_interval' do
      it 'returns POLL_INTERVAL from environment when set' do
        allow(ENV).to receive(:fetch).with("POLL_INTERVAL", "5Min").and_return("1Min")
        expect(FetchAndProcessJob.current_interval).to eq("1Min")
      end

      it 'returns default 5Min when POLL_INTERVAL not set' do
        allow(ENV).to receive(:fetch).with("POLL_INTERVAL", "5Min").and_return("5Min")
        expect(FetchAndProcessJob.current_interval).to eq("5Min")
      end
    end

    describe '.current_cron_schedule' do
      context 'when POLL_INTERVAL is 1Min' do
        before do
          allow(ENV).to receive(:fetch).with("POLL_INTERVAL", "5Min").and_return("1Min")
        end

        it 'returns */1 * * * *' do
          expect(FetchAndProcessJob.current_cron_schedule).to eq("*/1 * * * *")
        end
      end

      context 'when POLL_INTERVAL is 5Min' do
        before do
          allow(ENV).to receive(:fetch).with("POLL_INTERVAL", "5Min").and_return("5Min")
        end

        it 'returns */5 * * * *' do
          expect(FetchAndProcessJob.current_cron_schedule).to eq("*/5 * * * *")
        end
      end
    end

    describe '.update_schedule!' do
      before do
        # Mock SolidQueue classes
        stub_const('SolidQueue', Class.new)
        recurring_task_class = Class.new do
          def self.exists?(conditions)
            false
          end

          def self.find_by(conditions)
            nil
          end

          def self.create!(attributes)
            new
          end

          def destroy
            true
          end
        end
        stub_const('SolidQueue::RecurringTask', recurring_task_class)
      end

      context 'when POLL_INTERVAL is 1Min' do
        before do
          allow(ENV).to receive(:fetch).with("POLL_INTERVAL", "5Min").and_return("1Min")
        end

        it 'creates recurring task with */1 * * * * schedule' do
          expect(SolidQueue::RecurringTask).to receive(:create!).with(
            key: "fetch_and_process",
            schedule: "*/1 * * * *",
            class_name: "FetchAndProcessJob",
            static: false,
            description: "Fetch market data and process EMAs every 1Min"
          )

          FetchAndProcessJob.update_schedule!
        end
      end

      context 'when POLL_INTERVAL is 5Min' do
        before do
          allow(ENV).to receive(:fetch).with("POLL_INTERVAL", "5Min").and_return("5Min")
        end

        it 'creates recurring task with */5 * * * * schedule' do
          expect(SolidQueue::RecurringTask).to receive(:create!).with(
            key: "fetch_and_process",
            schedule: "*/5 * * * *",
            class_name: "FetchAndProcessJob",
            static: false,
            description: "Fetch market data and process EMAs every 5Min"
          )

          FetchAndProcessJob.update_schedule!
        end
      end

      context 'when existing recurring task exists' do
        let(:existing_task) { double('RecurringTask', destroy: true) }

        before do
          allow(SolidQueue::RecurringTask).to receive(:exists?).with(key: "fetch_and_process").and_return(true)
          allow(SolidQueue::RecurringTask).to receive(:find_by).with(key: "fetch_and_process").and_return(existing_task)
        end

        it 'destroys existing task before creating new one' do
          expect(existing_task).to receive(:destroy)
          expect(SolidQueue::RecurringTask).to receive(:create!)

          FetchAndProcessJob.update_schedule!
        end
      end

      context 'when SolidQueue is not defined' do
        before do
          hide_const('SolidQueue')
        end

        it 'returns early without error' do
          expect { FetchAndProcessJob.update_schedule! }.not_to raise_error
        end
      end

      context 'when create! fails' do
        before do
          allow(SolidQueue::RecurringTask).to receive(:create!).and_raise(StandardError, "Database error")
        end

        it 'logs error and returns false' do
          expect(Rails.logger).to receive(:error).with(/Failed to update schedule/)
          expect(FetchAndProcessJob.update_schedule!).to be false
        end
      end
    end

    describe 'acceptance criteria for Ticket T13' do
      it 'meets all requirements' do
        # ✓ Change POLL_INTERVAL in ENV to 1Min and 5Min
        # ✓ Verify FetchAndProcessJob cron schedule adjusts
        # ✓ Cron expression generated matches */1 * * * * vs. */5 * * * *
        # ✓ Test Type: Unit

        # Test 1Min interval
        allow(ENV).to receive(:fetch).with("POLL_INTERVAL", "5Min").and_return("1Min")
        expect(FetchAndProcessJob.current_cron_schedule).to eq("*/1 * * * *")

        # Test 5Min interval
        allow(ENV).to receive(:fetch).with("POLL_INTERVAL", "5Min").and_return("5Min")
        expect(FetchAndProcessJob.current_cron_schedule).to eq("*/5 * * * *")

        # Verify schedule adjustments work
        expect(FetchAndProcessJob.cron_schedule_for_interval("1Min")).to eq("*/1 * * * *")
        expect(FetchAndProcessJob.cron_schedule_for_interval("5Min")).to eq("*/5 * * * *")
      end
    end

    describe '#perform' do
      let(:job) { FetchAndProcessJob.new }
      let(:user) { double('User') }
      let(:trading_bot) { double('TradingBotService', run: true, last_error: nil) }

      before do
        allow(job).to receive(:get_active_symbols).and_return(['AAPL', 'MSFT'])
        allow(TradingBotService).to receive(:new).and_return(trading_bot)
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:debug)
        allow(Rails.logger).to receive(:warn)
        allow(Rails.logger).to receive(:error)
      end

      it 'processes all active symbols successfully' do
        expect(job).to receive(:process_symbol).with('AAPL')
        expect(job).to receive(:process_symbol).with('MSFT')

        job.perform
      end

      it 'logs processing summary' do
        allow(job).to receive(:process_symbol)

        expect(Rails.logger).to receive(:info).with(/Starting data fetch and processing/)
        expect(Rails.logger).to receive(:info).with(/Processing 2 symbols: AAPL, MSFT/)
        expect(Rails.logger).to receive(:info).with(/Completed in .* - Success: 2, Failed: 0/)

        job.perform
      end

      context 'when no symbols are active' do
        before do
          allow(job).to receive(:get_active_symbols).and_return([])
        end

        it 'logs warning and returns early' do
          expect(Rails.logger).to receive(:warn).with(/No active symbols to process/)
          expect(job).not_to receive(:process_symbol)

          job.perform
        end
      end

      context 'when symbol processing fails' do
        before do
          allow(job).to receive(:process_symbol).with('AAPL').and_raise(StandardError, "API Error")
          allow(job).to receive(:process_symbol).with('MSFT') # succeeds
        end

        it 'logs error but continues processing other symbols' do
          expect(Rails.logger).to receive(:error).with(/Failed to process AAPL/)
          expect(Rails.logger).to receive(:warn).with(/Failed symbols: AAPL/)

          job.perform
        end
      end
    end

    describe '#get_active_symbols' do
      let(:job) { FetchAndProcessJob.new }

      context 'when User model is available' do
        let(:user_class) { double('User') }
        let(:tracked_symbols_association) { double('Association') }

        before do
          stub_const('User', user_class)
          allow(user_class).to receive(:respond_to?).with(:joins).and_return(true)
        end

        it 'fetches symbols from user tracked_symbols' do
          allow(user_class).to receive(:joins).with(:tracked_symbols).and_return(tracked_symbols_association)
          allow(tracked_symbols_association).to receive(:where).and_return(tracked_symbols_association)
          allow(tracked_symbols_association).to receive(:distinct).and_return(tracked_symbols_association)
          allow(tracked_symbols_association).to receive(:pluck).with('tracked_symbols.symbol').and_return(['AAPL', 'MSFT'])

          symbols = job.send(:get_active_symbols)
          expect(symbols).to include('AAPL', 'MSFT')
        end
      end

      context 'when BotState is available' do
        let(:bot_state_class) { double('BotState') }

        before do
          stub_const('BotState', bot_state_class)
          allow(bot_state_class).to receive(:where).with(running: true).and_return(bot_state_class)
          allow(bot_state_class).to receive(:pluck).with(:symbol).and_return(['TSLA', 'NVDA'])
        end

        it 'includes symbols from running bot states' do
          symbols = job.send(:get_active_symbols)
          expect(symbols).to include('TSLA', 'NVDA')
        end
      end

      context 'when no symbols found from database sources' do
        before do
          allow(ENV).to receive(:fetch).with("WATCH_SYMBOLS", "AAPL,MSFT").and_return("GOOG,AMZN")
        end

        it 'falls back to environment variable' do
          symbols = job.send(:get_active_symbols)
          expect(symbols).to include('GOOG', 'AMZN')
        end
      end
    end

    describe '#process_symbol' do
      let(:job) { FetchAndProcessJob.new }
      
      context 'when trading bot succeeds' do
        it 'processes symbol successfully' do
          # Create a mock trading bot
          mock_trading_bot = instance_double('TradingBotService')
          allow(mock_trading_bot).to receive(:run).with(async: false).and_return(true)
          
          # Mock TradingBotService.new
          allow(TradingBotService).to receive(:new).and_return(mock_trading_bot)
          
          # Mock ENV.fetch for timeframe - updated to expect "5m"
          allow(ENV).to receive(:fetch).with("DEFAULT_TIMEFRAME", "5m").and_return("5m")
          
          expect {
            job.send(:process_symbol, "AAPL")
          }.not_to raise_error
        end
      end
      
      context 'when trading bot fails' do
        it 'raises error with trading bot error message' do
          # Create a mock trading bot that fails
          mock_trading_bot = instance_double('TradingBotService')
          allow(mock_trading_bot).to receive(:run).with(async: false).and_return(false)
          allow(mock_trading_bot).to receive(:last_error).and_return("Market closed")
          
          # Mock TradingBotService.new
          allow(TradingBotService).to receive(:new).and_return(mock_trading_bot)
          
          # Mock ENV.fetch for timeframe - updated to expect "5m"
          allow(ENV).to receive(:fetch).with("DEFAULT_TIMEFRAME", "5m").and_return("5m")
          
          expect {
            job.send(:process_symbol, "AAPL")
          }.to raise_error(StandardError, "TradingBotService failed: Market closed")
        end
      end
    end
  end
end 