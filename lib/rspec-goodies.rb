# frozen_string_literal: true

require "rspec/core"
require "rspec/goodies/helpers/sidekiq"
require "rspec/goodies/helpers/stubs"
require "rspec/goodies/matchers/collection"
require "rspec/goodies/matchers/sidekiq"

RSpec.configure do |config|
  config.include(RSpec::Goodies::Helpers::Sidekiq)
  config.include(RSpec::Goodies::Helpers::Stubs)
end
