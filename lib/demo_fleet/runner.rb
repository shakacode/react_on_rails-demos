# frozen_string_literal: true

module DemoFleet
  Result = Struct.new(:repo_id, :status, :value, :error, keyword_init: true)

  class Runner
    def initialize(concurrency:, &work)
      @concurrency = Integer(concurrency)
      raise ArgumentError, 'concurrency must be at least 1' if @concurrency < 1

      @work = work || proc { |plan| plan }
    end

    def run(plans)
      return [] if plans.empty?

      queue = Queue.new
      plans.each_with_index { |plan, index| queue << [index, plan] }
      results = Queue.new

      threads = workers(plans.length).map do
        Thread.new do
          loop do
            index, plan = queue.pop(true)
            results << [index, run_one(plan)]
          rescue ThreadError
            break
          end
        end
      end
      threads.each(&:join)

      Array.new(plans.length) { results.pop }.sort_by(&:first).map(&:last)
    end

    private

    def workers(plan_count)
      Array.new([@concurrency, plan_count].min)
    end

    def run_one(plan)
      value = @work.call(plan)
      Result.new(repo_id: plan.repo.id, status: 'success', value: value)
    rescue StandardError => e
      Result.new(repo_id: plan.repo.id, status: 'failure', error: e.message)
    end
  end
end
