# -*- encoding : utf-8 -*-

describe RabbitJobs do
  it 'should pass enqueue methods to publisher' do
    mock(RabbitJobs::Publisher).enqueue(Integer, 1, 2, "string")
    RabbitJobs.enqueue(Integer, 1, 2, "string")

    mock(RabbitJobs::Publisher).enqueue_to('default_queue', Integer, 1, 2, "string")
    RabbitJobs.enqueue_to('default_queue', Integer, 1, 2, "string")
  end
end