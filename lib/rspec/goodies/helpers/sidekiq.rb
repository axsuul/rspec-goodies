require "active_support"
require "active_support/core_ext/hash"

module RSpec
  module Goodies
    module Helpers
      module Sidekiq
        # Helper to briefly enable unique jobs functionality Only use this if you're explicitly testing unique job
        # behavior otherwise it is very unpredictable and it's best to disable it for normal tests
        def within_sidekiq_unique
          ::Sidekiq::Enterprise.unique!

          yield
        ensure
          disable_sidekiq_unique!
        end

        def disable_sidekiq_unique!
          ::Sidekiq.configure_server do |config|
            config.server_middleware do |chain|
              chain.remove(::Sidekiq::Enterprise::Unique::Server)
            end
          end

          ::Sidekiq.configure_client do |config|
            config.client_middleware do |chain|
              chain.remove(::Sidekiq::Enterprise::Unique::Client)
            end
          end
        end

        # Simulate job being performed within the entire middleware stack
        def perform_sidekiq_job(worker_class, *args)
          worker_class.perform_async(*args)

          actual_worker_class =
            if worker_class.is_a?(::Sidekiq::Worker::Setter)
              worker_class.instance_variable_get("@klass")
            else
              worker_class
            end

          actual_worker_class.process_job(actual_worker_class.jobs.last)
        end

        def process_sidekiq_payloads(payloads)
          payloads.each do |payload|
            payload_hash = ::Sidekiq.load_json(payload)
            worker_class = ::Sidekiq::Testing.constantize(payload_hash["class"])

            worker_class.process_job(payload_hash)
          end
        end

        def add_enqueued_sidekiq_job(worker_class:, args:, metadata: {}, jid: SecureRandom.hex, queue: :default)
          payload = ::Sidekiq.dump_json(
            metadata.merge(
              "jid" => jid,
              "class" => worker_class.to_s,
              "args" => args,
              "queue" => queue.to_s,
              "enqueued_at" => Time.current.to_f,
            ),
          )

          ::Sidekiq.redis do |redis|
            redis.sadd("queues", queue.to_s)
            redis.lpush("queue:#{queue}", payload)
          end

          payload
        end

        # Simulate job being added to retry queue (based off Sidekiq source code)
        def add_retry_sidekiq_job(
          worker_class:,
          args:,
          metadata: {},
          jid: SecureRandom.hex,
          retry_count: 2,
          retry_at: 1.hour.from_now
        )
          payload = ::Sidekiq.dump_json(
            metadata.merge(
              "jid" => jid,
              "class" => worker_class.to_s,
              "args" => args,
              "queue" => "default",
              "failed_at" => Time.now.to_f,
              "retry_count" => retry_count,
              "error_backtrace" => ["line1", "line2"],
            ),
          )

          ::Sidekiq.redis do |redis|
            redis.zadd("retry", retry_at.to_f.to_s, payload)
          end

          payload
        end

        def add_scheduled_sidekiq_job(worker_class:, args:, metadata: {}, jid: SecureRandom.hex)
          payload = ::Sidekiq.dump_json(
            metadata.merge(
              "jid" => jid,
              "class" => worker_class.to_s,
              "args" => args,
            ),
          )
          score = Time.now.to_f

          ::Sidekiq.redis do |redis|
            redis.zadd("schedule", score, payload)
          end

          payload
        end

        # Simulate job being worked on a worker so that's available via the Sidekiq::Workers.new API (based off Sidekiq
        # source code)
        def add_in_progress_sidekiq_job(worker_class:, args:, jid: SecureRandom.hex)
          @sidekiq_job_in_progress_thread_id ||= 1000
          @sidekiq_job_in_progress_count ||= 0

          process_id = "foo:#{SecureRandom.hex}"
          job_data = ::Sidekiq.dump_json(
            "queue" => "default",
            "payload" => {
              "jid" => jid,
              "class" => worker_class.to_s,
              "args" => args,
            },
            "run_at" => Time.current.to_i,
          )
          process_data = ::Sidekiq.dump_json(
            "hostname" => "foo",
            "started_at" => Time.now.to_f,
            "queues" => ["default"],
          )

          ::Sidekiq.redis do |redis|
            redis.incr("busy")
            redis.sadd("processes", process_id)
            redis.hmset(
              process_id, "info",
              process_data, "at",
              Time.current.to_f, "busy",
              @sidekiq_job_in_progress_count += 1,
            )
            redis.hmset("#{process_id}:work", @sidekiq_job_in_progress_thread_id += 1, job_data)
          end
        end
      end
    end
  end
end
