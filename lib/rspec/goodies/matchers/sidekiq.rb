require "rspec/matchers"
require "sidekiq/testing"

class SidekiqJobsEnqueuedMatcher
  include RSpec::Matchers

  attr_reader :new_jobs, :new_jobs_matching_properties

  def initialize(actual, worker_class, expected_size = nil, expected_properties = {})
    @actual = actual
    @worker_class = worker_class

    # Size is optional to be passed in
    if expected_size.is_a?(Hash)
      @expected_properties = expected_size
      @expected_size = nil
    else
      @expected_properties = expected_properties
      @expected_size = expected_size
    end

    # Normalize
    @expected_properties.stringify_keys!
  end

  def matches?
    # Get jobs before so that we only perform new jobs
    jobs_before = @worker_class.jobs.clone

    # Calls the actual block of the matcher
    @actual.call

    jobs_after = @worker_class.jobs
    @new_jobs = jobs_after - jobs_before

    @new_jobs_matching_properties = @new_jobs.select do |job|
      matched_count = 0

      @expected_properties.each do |key, value|
        case key
        when "args"
          # Coerce to an array unless it's a matcher
          value = Array(value) unless value.respond_to?(:base_matcher)

          expect(Array(job[key])).to match(value)
        when "at"
          # If nil, then we are looking for jobs that aren't scheduled
          if value.nil?
            expect(job.key?("at")).to eq false
          else
            # It's a float in job
            scheduled_at = job[key]

            expect(scheduled_at).to eq(value.to_f)
          end
        when "bid"
          expect(job[key]).to match(value)
        when "queue", "unique_for", "unique_until"
          expect(job[key].to_s).to eq(value.to_s)
        when "metadata"
          # Even though we call this metadata, it's actually just keys in the job hash. We iterate through each key so
          # that it also works on checking for nil values
          value.each do |metadata_key, metadata_value|
            expect(job[metadata_key]).to eq metadata_value
          end
        end

        matched_count += 1
      rescue RSpec::Expectations::ExpectationNotMetError => e
        # Doesn't contribute to matched_count if any expectations fail
      end

      matched_count == @expected_properties.count
    end

    # Check expected number of new jobs enqueued to match size if specified
    if @expected_size
      @new_jobs_matching_properties.size == @expected_size
    else
      @new_jobs_matching_properties.any?
    end
  end

  def new_jobs_sanitized
    (@new_jobs || []).map { |j| j.except("jid", "backtrace", "retry", "created_at", "enqueued_at") }
  end
end

RSpec::Matchers.define :have_sidekiq_jobs_enqueued do |*args|
  match do |actual|
    @matcher = SidekiqJobsEnqueuedMatcher.new(actual, *args)

    @matcher.matches?
  end

  failure_message do |_|
    "expected Sidekiq jobs to be enqueued with #{args.join(', ')} but instead found:\n\n#{@matcher.new_jobs_sanitized.pretty_inspect}"
  end

  def supports_block_expectations?
    true
  end
end

RSpec::Matchers.alias_matcher :have_sidekiq_job_enqueued, :have_sidekiq_jobs_enqueued
RSpec::Matchers.define_negated_matcher :not_have_sidekiq_jobs_enqueued, :have_sidekiq_jobs_enqueued

RSpec::Matchers.define :have_sidekiq_jobs_enqueued_and_performed do |*args|
  match do |actual|
    # Add the first arguments to the end since we are processing the chain from
    # last to first
    @worker_chain ||= []
    @worker_chain << args

    # Alias
    perform_jobs = actual

    while @worker_chain.any?
      args = @worker_chain.pop
      worker_class = args.first

      @matcher = SidekiqJobsEnqueuedMatcher.new(perform_jobs, *args)

      expect(@matcher.matches?).to eq true

      new_jobs_matching_properties = @matcher.new_jobs_matching_properties

      perform_jobs = lambda do
        new_jobs_matching_properties.each do |job|
          worker_class = job["class"]

          # Remove from queue after performing it
          Sidekiq::Queues.delete_for(job["jid"], job["queue"], worker_class)

          worker_class.constantize.process_job(job)
        end
      end
    end

    # Make sure we call perform jobs one last time if there's no more in chain
    perform_jobs.call
  end

  chain :thereafter do |*next_args|
    @worker_chain ||= []
    @worker_chain.prepend(next_args)
  end

  failure_message do |_|
    "expected Sidekiq jobs to be enqueued and performed with #{args.join(', ')} but instead found:\n\n#{@matcher.new_jobs_sanitized.pretty_inspect}"
  end

  def supports_block_expectations?
    true
  end
end

RSpec::Matchers.define :have_sidekiq_batch_with_callback_triggered do |event, callback_class|
  match do |actual|
    received_callbacks = Hash.new do |hash, key|
      hash[key] = {
        death: [],
        complete: [],
        success: [],
      }
    end

    sidekiq_batch_stub = ::Sidekiq::Batch.new.tap do |stub|
      # This can be called multiple times so track each time
      allow(stub).to receive(:on) do |actual_event, actual_callback_class, actual_callback_options|
        received_callbacks[actual_callback_class.name][actual_event].push(actual_callback_options)
      end

      allow(::Sidekiq::Batch).to receive(:new).and_return(stub)
    end

    # Ensure stuff happens within batch
    allow(sidekiq_batch_stub).to receive(:jobs).and_call_original

    actual.call

    # Only care about those received for event and callback
    relevant_received_callbacks = received_callbacks[callback_class.to_s][event]

    expect(relevant_received_callbacks).to be_any

    # Once block is complete, simulate Sidekiq batch callback is called by manually calling it ourselves since it
    # doesn't automatically get called in tests
    ::Sidekiq::Batch.new.tap do |batch|
      # Ensure created in redis so that we can access it
      batch.jobs {}

      # Simulate that callback is called for each time callback options were received
      relevant_received_callbacks.each do |callback_options|
        # Also simulate that callback options are converted to JSON and back to hash which is what happens in production
        callback_class.new.send(
          :"on_#{event}",
          ::Sidekiq::Batch::Status.new(batch.bid),
          JSON.parse(callback_options.to_json),
        )
      end
    end
  end

  failure_message do |_|
    "expected jobs to perform within Sidekiq batch with #{callback_class} callback to be triggered by #{event}"
  end

  def supports_block_expectations?
    true
  end
end

RSpec::Matchers.define_negated_matcher :not_have_sidekiq_batch_with_callback_triggered,
  :have_sidekiq_batch_with_callback_triggered
