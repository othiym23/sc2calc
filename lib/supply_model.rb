require 'abstract_resource_model'

class SupplyModel < AbstractResourceModel
  attr_accessor :logger

  COPIOUS_DEBUGGING = false

  def initialize(start_capacity = 0, start_used = 0)
    @used = { 0 => start_used }
    super(@used)

    @capacity = { 0 => start_capacity }
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

  def dump_available
    dump_queue(@capacity)
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
end
