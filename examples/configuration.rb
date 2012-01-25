require 'bundler/setup'
require 'rabbit_jobs'
require 'json'

RabbitJobs.configure do |c|
  c.host        "127.0.0.1"

  c.exchange 'test_exchange', durable: true, auto_delete: false

  c.queue 'rabbit_jobs_test1', durable: true, auto_delete: false, ack: true, arguments: {'x-ha-policy' => 'all'}
  c.queue 'rabbit_jobs_test2', durable: true, auto_delete: false, ack: true, arguments: {'x-ha-policy' => 'all'}
  c.queue 'rabbit_jobs_test3', durable: true, auto_delete: false, ack: true, arguments: {'x-ha-policy' => 'all'}
end

puts JSON.pretty_generate(RabbitJobs.config.to_hash)

puts JSON.pretty_generate(RabbitJobs.config.queues)

# 10.times {
  RabbitJobs.enqueue_to('rabbit_jobs_test1', Integer, 'to_s')
# }