class ConsumerModel
  attr_accessor :logger

  def initialize(used)
    @used = used
  end

  def consumed_at_time(time)
    accumulate(@used, @used.keys.select { |v| v <= time })
  end

  def consumed_after_time(time)
    accumulate(@used, @used.keys.select { |v| v > time })
  end

  def consumed_in_interval(start, finish)
    accumulate(@used, @used.keys.select { |v| (start...finish).include?(v) })
  end

  def dump_used
    dump_queue(@used)
  end

  protected

  attr_accessor :used

  def most_recent_in_queue(sparse_queue, time)
    sparse_queue[sparse_queue.keys.select {|tick| tick <= time }.sort.last] || 0
  end

  def accumulate(sparse_queue, tick_list)
    tick_list.collect { |v| sparse_queue[v] }.inject { |c,v| c + v } || 0
  end

  def update_queue(sparse_queue, time, amount)
    if sparse_queue.has_key?(time)
      sparse_queue[time] += amount
    else
      sparse_queue[time] = most_recent_in_queue(sparse_queue, time) + amount
    end
  end

  def intervals_at_time(queue, time)
    queue.keys.select { |event_tick| event_tick < time }.sort + [time]
  end

  # It's surprising that Ruby provides so little support for summing over
  # irregular intervals. This function produces a list of pairs that represent
  # intervals.
  def generate_pairs(point_array)
    pair_list = []

    point_array.each_index do |index|
      this_point = point_array[index]
      next_point = point_array[index + 1]

      if next_point
        pair_list << [this_point, next_point]
      end
    end

    pair_list
  end

  def dump_queue(queue)
    queue.keys.sort.map {|time| "#{Time.at(time).strftime("%M:%S")}: #{queue[time]}"}.join("\n")
  end

  def log_event(event)
    @logger.log_event(event) if @logger
  end
end