RSpec::Matchers.define :match_timestamp do |expected, decimal_places = nil|
  normalize = lambda do |value|
    value = DateTime.parse(value) if value.is_a?(String)

    # Compare floats since there can be sub-seconds
    normalized = value.to_f

    # Can be limited to decimals places (e.g. 0.002 can match 0.0019 if "3" is provided)
    normalized = normalized.round(decimal_places) if decimal_places

    normalized
  end

  match do |actual|
    normalize.call(actual) == normalize.call(expected)
  end

  failure_message do |actual|
    <<~MESSAGE
      expected that #{actual} (#{normalize.call(actual)}) would match timestamp #{expected}
      (#{normalize.call(expected)})"
    MESSAGE
  end
end
