require 'platform-api'

module Delayed
  module Workless
    module Scaler
      class HerokuCedar < Base
        extend Delayed::Workless::Scaler::HerokuClient
        @@mutex = Mutex.new

        def self.up
          workers_needed_now = self.workers_needed
          if workers_needed_now > self.min_workers and self.workers < workers_needed_now
            #p1 = fork { client.post_ps_scale(ENV['APP_NAME'], 'worker', workers_needed_now) }
            #Process.detach(p1)
            #client.post_ps_scale(ENV['APP_NAME'], 'worker', workers_needed_now)
            client.formation.update(ENV['APP_NAME'], 'worker', {'quantity' => workers_needed_now})
            @@mutex.synchronize do
              @workers = workers_needed_now
            end
            Rails.cache.write("workless-workers", @workers, expires_in: 15.minutes)
          end
        end

        def self.down
          unless self.jobs.count > 0 or self.workers == self.min_workers
            #p1 = fork { client.post_ps_scale(ENV['APP_NAME'], 'worker', self.min_workers) }
            #Process.detach(p1)
            #client.post_ps_scale(ENV['APP_NAME'], 'worker', self.min_workers)
            client.formation.update(ENV['APP_NAME'], 'worker', {'quantity' => self.min_workers})
            @@mutex.synchronize do
              @workers = self.min_workers
            end
            Rails.cache.write("workless-workers", @workers, expires_in: 15.minutes)
          end
        end

        def self.workers
          @@mutex.synchronize do
            return @workers ||= Rails.cache.fetch("workless-workers", :expires_in => 1.minutes, :race_condition_ttl => 10.seconds) do
              client.formation.list(ENV['APP_NAME']).each_with_object([]) { |p,a| a << p if p['type'] =~ /worker/i }.map { |p| p['quantity'].to_i }.sum
            end
          end
        end

        # Returns the number of workers needed based on the current number of pending jobs and the settings defined by:
        #
        # ENV['WORKLESS_WORKERS_RATIO']
        # ENV['WORKLESS_MAX_WORKERS']
        # ENV['WORKLESS_MIN_WORKERS']
        #
        def self.workers_needed
          [[(self.jobs.count.to_f / self.workers_ratio).ceil, self.max_workers].min, self.min_workers].max
        end

        def self.workers_ratio
          if ENV['WORKLESS_WORKERS_RATIO'].present? && (ENV['WORKLESS_WORKERS_RATIO'].to_i != 0)
            ENV['WORKLESS_WORKERS_RATIO'].to_i
          else
            100
          end
        end

        def self.max_workers
          ENV['WORKLESS_MAX_WORKERS'].present? ? ENV['WORKLESS_MAX_WORKERS'].to_i : 1
        end

        def self.min_workers
          ENV['WORKLESS_MIN_WORKERS'].present? ? ENV['WORKLESS_MIN_WORKERS'].to_i : 0
        end
      end
    end
  end
end
