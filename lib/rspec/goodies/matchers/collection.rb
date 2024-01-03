# Used to match if array includes elements and when order matters
RSpec::Matchers.define :include_in_order do |*args|
  match do |collection|
    expect_to_match = lambda do |value, matcher|
      # If composable matcher (e.g. a_string_matching(...) then we need to use a different expectation)
      if matcher.class.name.match?(/Matcher/)
        expect(value).to match(matcher)
      else
        expect(value).to eq(matcher)
      end
    end

    is_matched_in_order = false

    # Go through collection and try to find the first match
    collection.each_with_index do |element, collection_index|
      initial_matcher = args.first

      expect_to_match.call(element, initial_matcher)

      # If reaches here, that means we found the first match so let's see if the remaining also match in order
      is_matched_in_order = args[1..-1].each_with_index.all? do |pending_matcher, pending_matcher_index|
        expect_to_match.call(collection[collection_index + pending_matcher_index + 1], pending_matcher)

        true
      rescue RSpec::Expectations::ExpectationNotMetError
        false
      end

      # No need to search anymore once we found it
      break if is_matched_in_order
    rescue RSpec::Expectations::ExpectationNotMetError
      # Keep trying to find the first match
    end

    is_matched_in_order
  end
end

RSpec::Matchers.alias_matcher :a_collection_including_in_order, :include_in_order

# So we can do:
#
# expect(collection).to not_any(...)
#
# since we can't do:
#
# expect(collection).not_to all(...)
#
RSpec::Matchers.define_negated_matcher :not_any, :include
