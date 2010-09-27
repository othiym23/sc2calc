require 'consumer_model'

class SupplyModel < ConsumerModel
  attr_accessor :logger

  COPIOUS_DEBUGGING = false

  def initialize(start_capacity = 0, start_used = 0)
    @used = { 0 => start_used }
    super(@used)

    @capacity = { 0 => start_capacity }

    @type = 'supply'
  end

  def total_at_time(time)
    most_recent_in_queue(@capacity, time)
  end

  def used_at_time(time)
    consumed_at_time(time)
  end

  def available_at_time(time)
    total_at_time(time) - used_at_time(time)
  end

  def at_resource(amount)
    total_created = @capacity[@capacity.keys.sort.last]
    total_used    = consumed_after_time(0)
    if total_created < (total_used + amount)
      raise(DependencyError, "You require additional Pylons! Insufficient supply allocated!")
    end

    changes = @capacity.keys.sort
    puts "[DEBUG] changes: #{changes.join(', ')}" if COPIOUS_DEBUGGING
    if changes.size <= 1
      0
    else
      time_index = changes.each_index.detect do |index|
        first_time = changes[index]
        first_capacity = @capacity[first_time]
        puts "#{index}: first_capacity: #{first_capacity}" if COPIOUS_DEBUGGING

        next_time = changes[index + 1]
        next_capacity = @capacity[next_time]

        if next_capacity
          puts "#{index}: next_capacity: #{next_capacity}" if COPIOUS_DEBUGGING
          puts "#{index}: amount: #{amount}" if COPIOUS_DEBUGGING

          available = total_at_time(next_time) - consumed_in_interval(first_time, next_time)
          puts "#{index}: available: #{available}" if COPIOUS_DEBUGGING
          puts "#{index}: predicate: #{amount <= available}" if COPIOUS_DEBUGGING
          amount <= available
        else
          false
        end
      end

      supply_time = changes[time_index + 1]
      puts "[DEBUG] supply_time: #{supply_time}" if COPIOUS_DEBUGGING

      supply_time
    end
  end

  def add_capacity(time, amount)
    update_queue(@capacity, time, amount)
    log_event([time, 'add_supplies', @capacity[time]])
  end

  def dump_available
    dump_queue(@capacity)
  end

  def consume(amount, time)
    free = available_at_time(time)
    if amount > free
      raise(InvalidEconomyError, "The Starcraft economy does not allow deficit spending (deficit of #{amount - free} supply at #{time} seconds).")
    end

    updated_amount = (@used[time] || 0) + amount
    @used[time] = updated_amount
    puts "[DEBUG] #{updated_amount} supply used at #{time} seconds." if COPIOUS_DEBUGGING
    log_event([time, "#{@type}_used", "#{updated_amount}/#{total_at_time(time)}"])
  end
end
