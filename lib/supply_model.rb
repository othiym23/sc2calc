require 'sparse_queue_helper'

class SupplyModel
  include SparseQueueHelper

  attr_accessor :logger

  COPIOUS_DEBUGGING = false

  def initialize(start_capacity = 0, start_used = 0)
    @capacity = { 0 => start_capacity }
    @used = { 0 => start_used }
  end

  def available_at_time(time)
    most_recent_in_queue(@capacity, time)
  end

  def used_at_time(time)
    consumed_at_time(time)
  end

  def add_capacity(time, amount)
    update_queue(@capacity, time, amount)
    log_event([time, 'add_supplies', @capacity[time]])
  end

  def consume(amount, time)
    available = available_at_time(time)
    if amount > available
      raise(InvalidEconomyError, "The Starcraft economy does not allow deficit spending (deficit of #{amount - available} supply at #{time} seconds).")
    end

    updated_amount = (@used[time] || 0) + amount
    @used[time] = updated_amount
    puts "[DEBUG] #{updated_amount}/#{available} used at #{time} seconds." if COPIOUS_DEBUGGING
    log_event([time, "#{@type}_used", "#{updated_amount}/#{available}"])
  end

  def dump_available
    dump_queue(@capacity)
  end

  def dump_used
    dump_queue(@used)
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

  def log_event(*args)
    @logger.log_event(args) if @logger
  end
end
