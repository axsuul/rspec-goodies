RSpec::Matchers.define_negated_matcher :a_string_not_matching, :a_string_matching

RSpec::Matchers.define :match_url do |matched_url|
  match do |url|
    uri = Addressable::URI.parse(url)
    matched_uri = Addressable::URI.parse(matched_url)

    uri.host == matched_uri.host &&
    uri.path == matched_uri.path &&
    uri.query_values == matched_uri.query_values
  end

  failure_message do |url|
    "expected the url: #{url} to match the url: #{matched_url}"
  end
end
