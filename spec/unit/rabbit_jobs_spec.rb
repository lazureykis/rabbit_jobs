# -*- encoding : utf-8 -*-

describe RabbitJobs do
  it 'should pass publish methods to publisher' do
    mock(RabbitJobs::Publisher).publish(TestJob, nil, 1, 2, "string")
    RabbitJobs.publish(TestJob, nil, 1, 2, "string")

    mock(RabbitJobs::Publisher).publish_to('default_queue', TestJob, nil, 1, 2, "string")
    RabbitJobs.publish_to('default_queue', TestJob, nil, 1, 2, "string")
  end
end