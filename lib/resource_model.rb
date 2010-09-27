require 'sparse_queue_helper'

class ResourceModel
  include SparseQueueHelper

  attr_accessor :logger
  attr_reader :trip_time, :per_trip, :initial

  COPIOUS_DEBUGGING = false

  def initialize(type, trip_time, per_trip, start_harvesters = 0, start_amount = 0)
    @type      = type
    @trip_time = trip_time
    @per_trip  = per_trip

    @harvesters = {}
    @used  = {}

    if start_harvesters > 0
      @harvesters[0] = start_harvesters
    end

    @initial = start_amount
  end

  # at_time returns the difference between what gets generated during
  # a period and what was consumed during that period.
  #
  # It uses a list of intervals to partition the generation by the number of
  # harvesters / refiners available (although it models the gathering as a smooth
  # function instead of a collection of discrete harvesting events as in the
  # game.)
  #
  # TODO: Figure out the error of this function wrt time given.
  def at_time(time)
    resource = @initial

    puts "[START] initial: #{initial}" if COPIOUS_DEBUGGING
    puts "[START] time: #{time}" if COPIOUS_DEBUGGING

    if intervals_at_time(@harvesters, time).size > 1
      generate_pairs(intervals_at_time(@harvesters, time)).each_with_index do |pair, index|
        puts "[DEBUG] #{index}: STARTING LOOP" if COPIOUS_DEBUGGING
        start_time = pair[0]
        next_time  = pair[1]
        puts "#{index}: start_time: #{start_time}" if COPIOUS_DEBUGGING

        harvesters      = @harvesters[start_time]
        puts "#{index}: harvesters: #{harvesters}" if COPIOUS_DEBUGGING

        period          = next_time - start_time
        puts "#{index}: period: #{period}" if COPIOUS_DEBUGGING

        harvested       = time_to_resource(period, harvesters)
        resource       += harvested
        puts "#{index}: harvested: #{harvested}" if COPIOUS_DEBUGGING

        consumed        = consumed_in_interval(start_time, next_time)
        resource       -= consumed
        puts "#{index}: consumed: #{consumed}" if COPIOUS_DEBUGGING

        puts "#{index}: resource: #{resource}" if COPIOUS_DEBUGGING
      end
    else
      resource -= consumed_at_time(0)
      puts "0: resource: #{resource}" if COPIOUS_DEBUGGING
    end

    if resource < 0
      raise(InvalidEconomyError, "The Starcraft economy does not allow deficit spending (deficit of #{resource} #{@type} at #{time} seconds).")
    end

    puts "[FINISH] at_time: #{resource}" if COPIOUS_DEBUGGING
    resource
  end

  # This method performs the most subtle calculation in the entire build
  # calculator, and required a *LOT* of careful work to get correct.
  #
  # Do NOT try to tweak it unless you have a very good idea of how it works.
  #
  # A very important assumption made by this function is that it is going to
  # process the units passed to it in order, although it may dynamically
  # reorder the generated build based on resource availability.
  #
  # TODO: rewrite as a discrete system
  # TODO: rewrite as a recursive function (it's a disguised tail-recursive function right now anyway)
  def at_resource(amount)
    # Ensure there are harvesters available for the resource.
    raise(DependencyError, "#{@type} harvesters must be allocated to collect #{amount} #{@type}.") if amount > 0 && @harvesters.size == 0

    # 'amount' is how much resource we want to have available.
    #
    # 'initial' is how much of a given resource is available at the 
    # start of the build (e.g. 50 for minerals, 0 for gas).
    #
    # 'target' is an accumulator that, in the scope of the current
    # build step, contains the amount of resources consumed minus
    # the amount of resources generated.
    #
    # I gate 'target' at a maximum of 0 to keep the base case (nothing consumed
    # yet, and a produced unit of cost less than 50) from breaking the function.
    target = [amount - @initial, 0].max

    puts "[START] initial: #{@initial}" if COPIOUS_DEBUGGING
    puts "[START] amount #{@type}: #{amount}" if COPIOUS_DEBUGGING
    puts "[START] target: #{target}" if COPIOUS_DEBUGGING

    # Accumulator for the time necessary to harvest the desired amount of 
    # resources.
    resource_time = 0

    # Generate the set of intervals.
    changes = @harvesters.keys.sort
    changes.each_index do |index|
      puts "[DEBUG] STARTING LOOP #{index}" if COPIOUS_DEBUGGING

      resource_time = changes[index]
      next_time     = changes[index + 1]
      puts "#{index}: resource_time: #{resource_time}" if COPIOUS_DEBUGGING

      harvesters = @harvesters[resource_time]
      puts "#{index}: harvesters: #{harvesters}" if COPIOUS_DEBUGGING

      # If next_time is set, we're inside the list of assigned harvester
      # changes, not at the end of it.
      if next_time
        period     = next_time - resource_time
        puts "#{index}: period: #{period}" if COPIOUS_DEBUGGING

        # How much the harvesters have gathered during this period (which is
        # a none-too-accurate continuous approximation of a discrete system).
        harvested  = time_to_resource(period, harvesters)
        target    -= harvested
        puts "#{index}: harvested: #{harvested}" if COPIOUS_DEBUGGING

        # How much has been withdrawn from the resource pool to build things.
        consumed   = consumed_in_interval(resource_time, next_time)
        target    += consumed
        puts "#{index}: consumed: #{consumed}" if COPIOUS_DEBUGGING
        puts "#{index}: target: #{target}" if COPIOUS_DEBUGGING
      else
        puts "[DEBUG] no next time" if COPIOUS_DEBUGGING

        # Even after the harvester count changes are finished, there will be
        # a remaining set of consumed resources that need to be accounted for
        # in the calculation...
        remainder   = consumed_after_time(resource_time)
        puts "#{index}: remainder: #{remainder}" if COPIOUS_DEBUGGING

        target     += remainder
        puts "#{index}: target: #{target}" if COPIOUS_DEBUGGING

        # ...which is determined by calculating the time left to harvest the
        # leftover desired amount...
        period      = resource_to_time(target, harvesters)
        puts "#{index}: period: #{period}" if COPIOUS_DEBUGGING

        #  ...and then adding the calculated period to the time accumulator.
        resource_time += period
        puts "[FINISH]: resource_time: #{resource_time}" if COPIOUS_DEBUGGING
      end
    end

    resource_time
  end

  def consume(amount, time)
    available = at_time(time)
    if amount > available
      raise(InvalidEconomyError, "The Starcraft economy does not allow deficit spending (deficit of #{amount - available}  at #{time} seconds).")
    end

    updated_amount = (@used[time] || 0) + amount
    @used[time] = updated_amount
    puts "[DEBUG] #{updated_amount}/#{available} used at #{time} seconds." if COPIOUS_DEBUGGING
    log_event([time, "#{@type}_used", "#{updated_amount}/#{available}"])
  end

  def add_harvester(time)
    update_queue(@harvesters, time, 1)
    log_event([time, 'add_harvester', @harvesters[time]])
  end

  def add_harvesters(time, count)
    update_queue(@harvesters, time, count)
    log_event([time, 'add_harvesters', @harvesters[time]])
  end

  def remove_harvesters(time, count)
    update_queue(@harvesters, time, -count)
    log_event([time, 'remove_harvesters', @harvesters[time]])
  end

  def task_harvester(start_time, end_time)
    # remove a Probe from the work line while the warp point is set
    @harvesters[start_time] = most_recent_in_queue(@harvesters, start_time) - 1
    log_event([start_time, 'harvester_tasked', @harvesters[start_time]])

    # add the Probe back to the work line after the warp point is set
    @harvesters[end_time] = most_recent_in_queue(@harvesters, end_time) + 1
    log_event([end_time, 'harvester_returned', @harvesters[end_time]])
  end

  def dump_harvester_counts
    dump_queue(@harvesters)
  end

  def dump_used
    dump_queue(@used)
  end

  def harvesters_at_time(time)
    most_recent_in_queue(@harvesters, time)
  end

  def resource_to_time(resource, harvester_count)
    (resource.to_f / (harvester_count.to_f * @per_trip.to_f / @trip_time.to_f)).ceil
  end

  def time_to_resource(time, harvester_count)
    (time.to_f / @trip_time.to_f * harvester_count.to_f * @per_trip.to_f).floor
  end

  def total_consumed(resource_queue)
    accumulate(resource_queue, resource_queue.keys)
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

  def log_event(event)
    @logger.log_event(event) if @logger
  end
end
