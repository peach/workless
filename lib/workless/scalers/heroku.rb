require 'platform-api'

module Delayed
  module Workless
    module Scaler

      class Heroku < Base

        extend Delayed::Workless::Scaler::HerokuClient

        def self.up
          #client.put_workers(ENV['APP_NAME'], 1) if self.workers == 0
          client.formation.update(ENV['APP_NAME'], 'worker', {'quantity' => 1}) if self.workers == 0
        end

        def self.down
          #client.put_workers(ENV['APP_NAME'], 0) unless self.jobs.count > 0 or self.workers == 0
          client.formation.update(ENV['APP_NAME'], 'worker', {'quantity' => 0}) unless self.jobs.count > 0 or self.workers == 0
        end

        def self.workers
          #client.get_ps(ENV['APP_NAME']).body.count { |p| p["process"] =~ /worker\.\d?/ }
          client.formation.list(ENV['APP_NAME']).each_with_object([]) { |p,a| a << p if p['type'] =~ /worker/i }.map { |p| p['quantity'].to_i }.sum
        end

      end

    end
  end
end
