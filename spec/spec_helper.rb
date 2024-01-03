require "byebug"
require "rspec-goodies"
require "timecop"

RSpec.configure do |config|
  # Filters
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true

  config.mock_with :rspec do |mocks|
    # So we can stub Rails.application
    mocks.allow_message_expectations_on_nil = true
  end

  config.before(:all) do
    Sidekiq::Worker.clear_all
  end

  config.before do
    Sidekiq::Worker.clear_all
    Timecop.return
  end
end
