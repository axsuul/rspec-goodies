require "spec_helper"

describe "Collection Matchers" do
  describe "#collection_including_in_order" do
    it "only matches if collection includes elements in order" do
      collection = [1, 2, 3, 1, 3, 2]

      expect(collection).to match(a_collection_including_in_order(2))
      expect(collection).to match(a_collection_including_in_order(1, 2))
      expect(collection).to match(a_collection_including_in_order(2, 3))
      expect(collection).to match(a_collection_including_in_order(1, 3))
      expect(collection).to match(a_collection_including_in_order(1, 3, 2))
      expect(collection).not_to match(a_collection_including_in_order(1, 1))
      expect(collection).not_to match(a_collection_including_in_order(2, 1))
      expect(collection).not_to match(a_collection_including_in_order(2, 2))
      expect(collection).not_to match(a_collection_including_in_order(3, 1, 2))
      expect(collection).not_to match(a_collection_including_in_order(1, 2, 2))
    end

    it "handle nil elements in matchers" do
      collection_1 = ["foo", "bar", "baz"]
      collection_2 = ["foo", "bar", nil]

      expect(collection_1).not_to match(a_collection_including_in_order("foo", "bar", nil))
      expect(collection_2).to match(a_collection_including_in_order("foo", "bar", nil))
    end

    it "doesn't match if not the same type" do
      collection = ["1", "2"]

      expect(collection).not_to match(a_collection_including_in_order(2))
      expect(collection).not_to match(a_collection_including_in_order(1, 2))
      expect(collection).to match(a_collection_including_in_order("2"))
      expect(collection).to match(a_collection_including_in_order("1", "2"))
    end

    it "can be used in conjunction with hash composable matchers" do
      collection = [1, { foo: "1", bar: "2", baz: "3" }]

      expect(collection).to match(a_collection_including_in_order(1, a_hash_including(foo: "1")))
      expect(collection).not_to match(a_collection_including_in_order(1, a_hash_including(foo: "2")))
    end

    it "can be used in conjunction with string composable matchers" do
      collection = ["foo", "bar", "baz"]

      expect(collection).to match(a_collection_including_in_order("foo", a_string_matching(/ar/), a_string_matching(/az/)))
      expect(collection).to match(a_collection_including_in_order(a_string_matching(/oo/), "bar", a_string_matching(/az/)))
      expect(collection).not_to match(a_collection_including_in_order("foo", a_string_matching(/az/), a_string_matching(/ar/)))
      expect(collection).not_to match(a_collection_including_in_order(a_string_matching(/zz/), "bar", a_string_matching(/az/)))
    end

    it "can be used in conjunction with anything composable matchers" do
      collection = ["foo", 1, "baz"]

      expect(collection).to match(a_collection_including_in_order("foo", anything, "baz"))
      expect(collection).to match(a_collection_including_in_order(anything, 1, anything))
      expect(collection).to match(a_collection_including_in_order(anything, anything, anything))
    end
  end
end
