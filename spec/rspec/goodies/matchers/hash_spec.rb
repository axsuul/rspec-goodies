require "spec_helper"

describe "Hash Matchers" do
  describe "#a_hash_without_keys" do
    it "only matches if hash doesn't have keys" do
      hash = {
        "a" => {
          "aa" => {
            "aaa" => {},
          },
        },
        "b" => {
          "bb" => {},
          "bb-1" => {},
        },
      }

      expect(hash).not_to match(a_hash_without_keys("a"))
      expect(hash).not_to match(a_hash_without_keys("b"))
      expect(hash).to match(a_hash_without_keys("c"))
      expect(hash).to match(
        a_hash_including(
          "a" => a_hash_including(
            "aa" => a_hash_without_keys("aaaa"),
          ),
        ),
      )
      expect(hash).not_to match(
        a_hash_including(
          "a" => a_hash_including(
            "aa" => a_hash_without_keys("aaa"),
          ),
        ),
      )
      expect(hash).not_to match(
        a_hash_including(
          "b" => a_hash_without_keys("bb", "bb-1"),
        ),
      )
      expect(hash).not_to match(
        a_hash_including(
          "b" => a_hash_without_keys("cc", "bb-1"),
        ),
      )
      expect(hash).to match(
        a_hash_including(
          "b" => a_hash_without_keys("cc", "cc-1"),
        ),
      )
    end
  end
end
