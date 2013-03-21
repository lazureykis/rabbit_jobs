# -*- encoding : utf-8 -*-
require 'spec_helper'

describe RabbitJobs do
  it 'should pass publish methods to publisher' do
    mock(RJ::Publisher).publish_to('default_queue', TestJob, nil, 1, 2, "string")
    RJ.publish_to('default_queue', TestJob, nil, 1, 2, "string")

    mock(RJ::Publisher).direct_publish_to('default_queue', 'hello', {name: "my_exchange"})
    RJ.direct_publish_to('default_queue', 'hello', {name: "my_exchange"})
  end
end