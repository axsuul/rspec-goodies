require "spec_helper"
require "active_support"
require "active_support/values/time_zone"

describe "DateTime Matchers" do
  before do
    Time.zone = ActiveSupport::TimeZone.new("America/Los_Angeles")
  end

  describe "#match_timestamp" do
    it "matches if timestamps are equal" do
      timestamp = Time.utc(2018, 1, 1, 0, 0, 0, 10)

      expect(timestamp).to match_timestamp(timestamp)
      expect(timestamp).to match_timestamp(Time.utc(2018, 1, 1, 0, 0, 0, 10))
      expect(timestamp).not_to match_timestamp(Time.utc(2018, 1, 1, 0, 0, 0, 9))
    end

    it "matches if timestamps with timezones are equal" do
      timestamp = Time.zone.local(2018, 1, 1, 0, 0, 0, 10)

      expect(timestamp).to match_timestamp(timestamp)
      expect(timestamp).to match_timestamp(Time.zone.local(2018, 1, 1, 0, 0, 0, 10))
      expect(timestamp).not_to match_timestamp(Time.zone.local(2018, 1, 1, 0, 0, 0, 9))
    end

    it "can match within decimal places" do
      timestamp = Time.utc(2018, 1, 1, 0, 0, 0, 200)

      expect(timestamp).not_to match_timestamp(Time.utc(2018, 1, 1, 0, 0, 0, 190))

      # 0.0002 seconds still matches 0.00019 seconds
      expect(timestamp).to match_timestamp(Time.utc(2018, 1, 1, 0, 0, 0, 190), 4)
    end

    it "can match timestamp string with timestamp object" do
      expect(Time.utc(2018, 1, 1, 0, 0, 0)).to match_timestamp("2018-01-01T00:00:00Z")
      expect(Time.utc(2018, 1, 1, 0, 0, 0)).not_to match_timestamp("2018-01-01T00:00:01Z")

      expect("2018-01-01T00:00:00Z").to match_timestamp(Time.utc(2018, 1, 1, 0, 0, 0))
      expect("2018-01-01T00:00:00Z").not_to match_timestamp(Time.utc(2018, 1, 1, 0, 0, 1))
    end
  end
end
