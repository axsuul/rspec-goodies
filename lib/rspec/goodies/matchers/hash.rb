# Used to match if hash doesn't have all keys
RSpec::Matchers.define :not_have_keys do |*keys|
  match do |hash|
    keys.all? { |k| !hash.key?(k) }
  end
end

RSpec::Matchers.alias_matcher :a_hash_without_keys, :not_have_keys
