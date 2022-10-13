class CounterChannel < ApplicationCable::Channel
  def subscribed
    stream_from "counter"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
