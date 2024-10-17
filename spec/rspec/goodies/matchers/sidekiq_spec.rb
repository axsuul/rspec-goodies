require "spec_helper"
require "active_support"
require "active_support/core_ext/numeric"
require "sidekiq"

class BaseWorker
  include Sidekiq::Worker
end

class GrandparentWorker < BaseWorker
  def perform(count, parent_count)
    count.times do
      ParentWorker.set(queue: :critical).perform_async(parent_count)
    end
  end
end

class ParentWorker < BaseWorker
  def perform(count)
    count.times do
      ChildWorker.set(queue: :default).perform_async
    end
  end
end

class ChildWorker < BaseWorker
  def perform
    GrandparentWorker.set(queue: :default).perform_async(2, 1)
  end
end

RSpec.describe "Sidekiq Matchers" do
  describe "#have_sidekiq_jobs_enqueued" do
    it "can match number of enqueued worker jobs" do
      expect do
        GrandparentWorker.perform_async(5, 2)
        GrandparentWorker.perform_async(3, 2)
        ParentWorker.perform_async(2)
      end.to have_sidekiq_jobs_enqueued(GrandparentWorker, 2)
        .and have_sidekiq_jobs_enqueued(ParentWorker, 1)
    end

    it "can match no enqueued jobs" do
      expect do
        ParentWorker.perform_async(2)
      end.to have_sidekiq_jobs_enqueued(GrandparentWorker, 0)
        .and have_sidekiq_jobs_enqueued(ParentWorker, 1)
    end

    it "doesn't match if number of jobs enqueued isn't correct" do
      expect do
        expect do
          GrandparentWorker.perform_async(5, 2)
          GrandparentWorker.perform_async(5, 2)
          GrandparentWorker.drain
        end.to have_sidekiq_jobs_enqueued(GrandparentWorker, 1)
          .and have_sidekiq_jobs_enqueued(ParentWorker, 1)
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected Sidekiq jobs to be enqueued/)
    end

    it "can match enqueued jobs with properties" do
      expect do
        GrandparentWorker.set(queue: :critical).perform_async(5, 2)
        ParentWorker.set(queue: :default).perform_async(2)
      end.to have_sidekiq_jobs_enqueued(GrandparentWorker, queue: :critical)
        .and have_sidekiq_jobs_enqueued(ParentWorker, queue: :default)
        .and not_have_sidekiq_jobs_enqueued(GrandparentWorker, queue: :default)
        .and not_have_sidekiq_jobs_enqueued(ParentWorker, queue: :critical)
    end

    it "can match job arguments" do
      expect do
        GrandparentWorker.perform_async(5, 2)
        GrandparentWorker.perform_async(3, 2)
        ParentWorker.perform_async(2)
      end.to have_sidekiq_jobs_enqueued(GrandparentWorker, 1, args: [5, 2])
        .and have_sidekiq_jobs_enqueued(GrandparentWorker, 1, args: [3, 2])
        .and have_sidekiq_jobs_enqueued(ParentWorker, 1, args: 2)
    end

    it "can match scheduled timestamp" do
      Timecop.freeze(Time.utc(2018, 1, 1, 0, 0, 0))

      expect do
        ParentWorker.perform_in(1.minute, 1)
      end.to have_sidekiq_jobs_enqueued(ParentWorker, 1, args: [1], at: Time.utc(2018, 1, 1, 0, 1, 0))

      expect do
        ParentWorker.perform_in(2.minutes, 1)
      end.not_to have_sidekiq_jobs_enqueued(ParentWorker, 1, args: [1], at: Time.utc(2018, 1, 1, 0, 1, 0))

      expect do
        ParentWorker.perform_at(2.minutes.from_now, 1)
      end.to have_sidekiq_jobs_enqueued(ParentWorker, 1, args: [1], at: Time.utc(2018, 1, 1, 0, 2, 0))

      expect do
        ParentWorker.perform_at(2.minutes.from_now.to_f, 1)
      end.to have_sidekiq_jobs_enqueued(ParentWorker, 1, args: [1], at: Time.utc(2018, 1, 1, 0, 2, 0))
    end

    it "doesn't match if not scheduled" do
      Timecop.freeze(Time.utc(2018, 1, 1, 0, 0, 0))

      expect do
        ParentWorker.perform_async(1)
      end.to not_have_sidekiq_jobs_enqueued(ParentWorker, 1, args: [1], at: Time.utc(2018, 1, 1, 0, 1, 0))
    end

    it "can match unscheduled" do
      expect do
        ParentWorker.perform_in(1.minute, 1)
      end.to have_sidekiq_jobs_enqueued(ParentWorker, 0, at: nil)

      expect do
        ParentWorker.perform_async(1)
      end.to have_sidekiq_jobs_enqueued(ParentWorker, 1, at: nil)
    end

    it "doesn't match if job arguments don't match" do
      expect do
        expect do
          GrandparentWorker.perform_async(5, 2)
          GrandparentWorker.perform_async(3, 2)
          ParentWorker.perform_async(2)
        end.to have_sidekiq_jobs_enqueued(GrandparentWorker, 1, args: [5, 2])
          .and have_sidekiq_jobs_enqueued(GrandparentWorker, 1, args: [4, 2])
          .and have_sidekiq_jobs_enqueued(ParentWorker, 2, args: 2)
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected Sidekiq jobs to be enqueued/)
    end

    it "can match queue, arguments and size" do
      expect do
        GrandparentWorker.set(queue: :critical).perform_async(5, 2)
      end.to have_sidekiq_jobs_enqueued(GrandparentWorker, 1, queue: :critical, args: [5, 2])

      expect do
        GrandparentWorker.set(queue: :default).perform_async(5, 2)
      end.not_to have_sidekiq_jobs_enqueued(GrandparentWorker, 1, queue: :critical, args: [5, 2])

      expect do
        GrandparentWorker.set(queue: :critical).perform_async(5, 3)
      end.not_to have_sidekiq_jobs_enqueued(GrandparentWorker, 1, queue: :critical, args: [5, 2])

      expect do
        GrandparentWorker.set(queue: :critical).perform_async(5, 2)
        GrandparentWorker.set(queue: :critical).perform_async(5, 2)
      end.not_to have_sidekiq_jobs_enqueued(GrandparentWorker, 1, queue: :critical, args: [5, 2])
    end

    it "can match metadata" do
      expect do
        GrandparentWorker.set("_organization_id" => 10, "_external_service_type_id" => 20).perform_async(5, 2)
      end.to have_sidekiq_jobs_enqueued(GrandparentWorker, 1,
        args: [5, 2],
        metadata: {
          "_organization_id" => 10,
          "_external_service_type_id" => 20,
        },
      )

      # Args don't match
      expect do
        GrandparentWorker.set("_organization_id" => 10, "_external_service_type_id" => 20).perform_async(5, 2)
      end.not_to have_sidekiq_jobs_enqueued(GrandparentWorker, 1,
        args: [5, 5],
        metadata: {
          "_organization_id" => 10,
          "_external_service_type_id" => 20,
        },
      )

      # Metadata doesn't match
      expect do
        GrandparentWorker.set("_organization_id" => 10, "_external_service_type_id" => 20).perform_async(5, 2)
      end.not_to have_sidekiq_jobs_enqueued(GrandparentWorker, 1,
        args: [5, 2],
        metadata: {
          "_organization_id" => 20,
          "_external_service_type_id" => 10,
        },
      )

      # Metadata doesn't match
      expect do
        GrandparentWorker.set("_organization_id" => 10, "_external_service_type_id" => 20).perform_async(5, 2)
      end.not_to have_sidekiq_jobs_enqueued(GrandparentWorker, 1,
        args: [5, 2],
        metadata: {
          "_organization_id" => 10,
          "_external_service_type_id" => 10,
        },
      )
    end

    it "can skip matching nil metadata" do
      expect do
        GrandparentWorker.set("_organization_id" => 10, "_external_service_type_id" => 20).perform_async(5, 2)
      end.to have_sidekiq_jobs_enqueued(GrandparentWorker, 1,
        args: [5, 2],
        metadata: {
          "_organization_id" => 10,
          "_external_service_type_id" => 20,
          "_random_metadata" => nil,
        },
      )
    end

    it "can use composable matchers with args" do
      expect do
        GrandparentWorker.perform_async(5, 2)
      end.to have_sidekiq_jobs_enqueued(GrandparentWorker, 1, args: a_collection_including(5))
        .and have_sidekiq_jobs_enqueued(GrandparentWorker, 1, args: a_collection_including(2))
        .and not_have_sidekiq_jobs_enqueued(GrandparentWorker, 1, args: a_collection_including(4))
    end
  end

  describe "#have_sidekiq_jobs_enqueued_and_performed" do
    it "can match enqueued worker jobs which are then performed in a chained manner" do
      expect do
        GrandparentWorker.perform_async(5, 2)
        GrandparentWorker.drain
      end.to have_sidekiq_jobs_enqueued_and_performed(ParentWorker, 5, queue: :critical)
        .thereafter(ChildWorker, 10, queue: :default)
        .thereafter(GrandparentWorker, 10, queue: :default)

      expect(ParentWorker.jobs.size).to eq 20
    end

    it "still matches if number of jobs isn't provided" do
      expect do
        GrandparentWorker.perform_async(5, 2)
        GrandparentWorker.drain
      end.to have_sidekiq_jobs_enqueued_and_performed(ParentWorker, 5, queue: :critical)
        .thereafter(ChildWorker, queue: :default)
    end

    it "doesn't match if number of jobs enqueued isn't correct" do
      expect do
        expect do
          GrandparentWorker.perform_async(5, 2)
          GrandparentWorker.drain
        end.to have_sidekiq_jobs_enqueued_and_performed(ParentWorker, 5, queue: :critical)
          .thereafter(ChildWorker, 9, queue: :default)
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected Sidekiq jobs to be enqueued/)
    end

    it "doesn't match if jobs aren't enqueued in the correct queue" do
      expect do
        expect do
          GrandparentWorker.perform_async(5, 2)
          GrandparentWorker.drain
        end.to have_sidekiq_jobs_enqueued_and_performed(ParentWorker, 5, queue: :critical)
          .thereafter(ChildWorker, 10, queue: :critical)
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected Sidekiq jobs to be enqueued/)
    end
  end
end
