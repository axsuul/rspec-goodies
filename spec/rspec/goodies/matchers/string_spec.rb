require "spec_helper"

describe "String Matchers" do
  describe "#a_string_not_matching" do
    it "only matches if string doesn't match" do
      hash = {
        "foo" => "111",
      }

      expect(hash).to match(
        a_hash_including(
          "foo" => a_string_not_matching(/112/)
        ),
      )

      expect(hash).not_to match(
        a_hash_including(
          "foo" => a_string_not_matching(/111/)
        ),
      )
    end
  end
end
