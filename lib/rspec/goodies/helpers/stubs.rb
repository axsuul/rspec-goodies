module RSpec
  module Goodies
    module Helpers
      module Stubs
        def stub_service_as_spy(klass)
          service_stub = class_spy(klass)
          stub_const(klass.to_s, service_stub)

          service_stub
        end

        def stub_rails_logger_as_spy
          instance_spy("ActiveSupport::Logger").tap do |stub|
            allow(::Rails).to receive(:logger).and_return(stub)
          end
        end

        def stub_class_const(klass, const_string, value)
          raise ArgumentError, "a Class or Module must be passed in" if !klass.is_a?(Class) && !klass.is_a?(Module)

          # Check that constant actually exists. Also by calling klass here we ensure it's loaded before stubbing
          # constant
          unless klass.const_defined?(const_string)
            raise Exception, "Tried to stub #{klass}::#{const_string} but it doesn't exist!"
          end

          stub_const("#{klass.name}::#{const_string}", value)
        end

        # Stubs existing constant with resulting hash deep merged with existing hash and hash passed in
        def stub_merged_hash_class_const(klass, const_string, hash)
          raise ArgumentError, "must pass in hash" unless hash.is_a?(Hash)

          existing_hash = klass.const_get(const_string)

          stub_class_const(klass, const_string, existing_hash.deep_merge(hash))
        end

        # Stub environment variable so that it doesn't leak out of tests
        def stub_env(name, value)
          allow(ENV).to receive(:[]).with(name).and_return(value)
        end

        # Only works with nested credentials for now
        def stub_rails_credentials(stubbed_config)
          raise NotImplementedError, "Rails not found" unless Object.const_defined?(:Rails)

          credentials = ::Rails.application.credentials
          credentials_config = credentials.config
          stubbed_credentials_config = credentials_config

          stubbed_config.each do |key, key_stubbed_config|
            key = key.to_sym

            case key_stubbed_config
            when Hash
              key_stubbed_config.each do |child_key, _|
                if !credentials_config.key?(key) || !credentials_config[key].key?(child_key)
                  raise ArgumentError, "Tried to stub Rails credential #{key}: #{child_key} but it doesn't exist!"
                end
              end

              # Merge in existing credentials so we don't break accessing other credentials
              stubbed_credentials_config[key].merge!(key_stubbed_config)
            when String
              # Not nested so set it directly
              stubbed_credentials_config[key] = key_stubbed_config
            end
          end

          allow(::Rails.application).to receive(:credentials).and_return(OpenStruct.new(stubbed_credentials_config))
        end
      end
    end
  end
end
