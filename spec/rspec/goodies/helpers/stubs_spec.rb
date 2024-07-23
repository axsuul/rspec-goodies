require "spec_helper"

class Rails
  def self.application; end
end

class StubTestClass
  FOO = "bar".freeze
  NESTED_HASH = {
    listing_variant: {
      available_quantity: {
        minimum: nil,
        maximum: 5,
        groupable: {
          update: {
            limit: 500,
          },
        },
      },
      on_hand_quantity: {},
    },
  }.freeze
end

describe RSpec::Goodies::Helpers::Stubs do
  describe "#stub_class_const" do
    it "stubs class constant" do
      stub_class_const(StubTestClass, "FOO", "baz")

      expect(StubTestClass::FOO).to eq "baz"
    end

    it "raises exception if class does not have constant defined" do
      expect { stub_class_const(StubTestClass, "MOO", "baz") }.to raise_error(Exception)
    end
  end

  describe "#stub_merged_hash_class_const" do
    it "can stub class constant with hash merged into existing" do
      stub_merged_hash_class_const(StubTestClass, "NESTED_HASH",
        listing_variant: {
          available_quantity: {
            maximum: 2,
            groupable: {
              create: {
                limit: 0,
              },
              update: {
                limit: 250,
              },
            },
          },
        },
        listing: {
          external_service_state: {},
        },
      )

      expect(StubTestClass::NESTED_HASH).to eq(
        listing_variant: {
          available_quantity: {
            minimum: nil,
            maximum: 2,
            groupable: {
              create: {
                limit: 0,
              },
              update: {
                limit: 250,
              },
            },
          },
          on_hand_quantity: {},
        },
        listing: {
          external_service_state: {},
        },
      )
    end
  end

  describe "#stub_rails_credentials" do
    it "raises exception if any of the credential keys don't exist" do
      credentials = double("credentials")
      allow(credentials).to receive(:config).and_return(
        postgres: {
          database: "bar",
        },
      )
      allow(Rails.application).to receive(:credentials).and_return(credentials)

      # Sanity check
      expect(Rails.application.credentials.config).to match(
        postgres: {
          database: "bar",
        },
      )

      expect { stub_rails_credentials(does_not_exist: { bar: "baz" }) }.to raise_error(ArgumentError)
      expect { stub_rails_credentials(postgres: { database: "foo", does_not_exist: "baz" }) }.to raise_error(ArgumentError)
    end

    it "can stub existing credentials partially" do
      credentials = double("credentials")
      allow(credentials).to receive(:config).and_return(
        postgres: {
          database: "bar",
          default_username: "vanilla",
        },
        segment: {
          backend_write_key: "1234",
        },
        encryption_key: "1234",
        fetch_key: "1234",
      )
      allow(Rails.application).to receive(:credentials).and_return(credentials)

      stub_rails_credentials(
        postgres: {
          database: "foo",
        },
        segment: {
          backend_write_key: "0000",
        },
        encryption_key: "0000",
      )

      expect(Rails.application.credentials.postgres[:database]).to eq "foo"
      expect(Rails.application.credentials.segment[:backend_write_key]).to eq "0000"
      expect(Rails.application.credentials.encryption_key).to eq "0000"

      # Doesn't touch other credentials
      expect(Rails.application.credentials.postgres[:default_username]).to eq "vanilla"
      expect(Rails.application.credentials.fetch_key).to eq "1234"
    end
  end
end
