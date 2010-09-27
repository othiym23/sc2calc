require 'inventory'
require 'resource_model'
require 'supply_model'

class DependencyError < StandardError ; end

class InvalidEconomyError < StandardError ; end

# The clock ticks each second.
# With every tick,
# 1. See if any mining units have finished gathering.
# 2. See if any gas units have finished gathering.
# 3. See if any units have started building.
#    - T requires the builder be occupied for duration of build time.
#    - P only requires the builder be removed from other queues long enough to
#      start unit warp.
#    - Z consumes builder, permanently removes from other queue.
# 4. See if any units have finished building.

# Units can only start building if:
#  - their dependencies are available.
#  - enough minerals have accrued.
#  - enough gas has accrued.

# QUEUES:
# 1. Mining workers.
# 2. Refinery workers.
# 3. Build workers.
#
# Initial build will presuppose that all workers are kept occupied.

class Event
  attr_reader :unit, :start_time, :finish_time

  def initialize(unit, start_time, finish_time)
    @unit = unit
    @start_time = start_time
    @finish_time = finish_time
  end
end

class BuildEvent < Event
  attr_reader :mineral_at_end, :gas_at_end, :supply_used, :supply_available

  def initialize(unit, start_time, finish_time, mineral_at_end, gas_at_end, supply_used, supply_available)
    super(unit, start_time, finish_time)
    @mineral_at_end = mineral_at_end
    @gas_at_end = gas_at_end
    @supply_used = supply_used
    @supply_available = supply_available
  end
end

class BuildOrderPrinter
  def self.print(build_order)
    build_order.each do |event|
      puts "#{Time.at(event.start_time).strftime("%M:%S")}-#{Time.at(event.finish_time).strftime("%M:%S")}: #{"%7s" % "#{event.supply_used}/#{event.supply_available}"} M: #{"%4d" % event.mineral_at_end} G: #{"%4d" % event.gas_at_end} #{event.unit['name']}"
    end
  end

  nil
end

class Built
  attr_reader :unit, :start_time

  def initialize(unit, start_time = 0)
    @unit = unit
    @start_time = start_time
  end
end

class Producer < Built
  attr_reader :unit, :start_time, :queue

  def initialize(unit, start_time = 0, queue = [])
    super(unit, start_time)
    @queue = queue
  end
end

class BuildOrder
  attr_reader :supply_queue, :supply_used, :built

  COPIOUS_DEBUGGING = false

  # the following are conservative approximations
  # average duration of harvest per harvester with optimal base location
  MINE_TIME = 8
  MINERAL_PER_TRIP = 5

  GAS_TIME = 4
  GAS_PER_TRIP = 4

  WARP_PLACEMENT_TIME = 2

  START_HARVESTERS = 6
  START_MINERALS   = 50

  def self.queue_up_build(info, unit_id_list)
    build = BuildOrder.new(info)

    unit_id_list.each do |id|
      build.enqueue_unit(info.lookup(id))
    end

    build
  end

  def initialize(info)
    @info = info

    @minerals = ResourceModel.new('minerals', MINE_TIME, MINERAL_PER_TRIP, START_HARVESTERS, START_MINERALS)
    @minerals.logger = self

    @gas = ResourceModel.new('gas', GAS_TIME, GAS_PER_TRIP)
    @gas.logger = self

    @supply = SupplyModel.new(10, 6)

    @producer_list = {}
    @producer_list.default = []
    @producer_list['pbn'] += [ Producer.new(@info.lookup('pbn')) ]
    6.times { @producer_list['pup'] += [Producer.new(@info.lookup('pup'))] }

    @built = {}
    @built.default = []
    @built['pbn'] += [ Built.new(@info.lookup('pbn')) ]
    6.times { @built['pup'] += [Built.new(@info.lookup('pup'))] }

    @pending_build_queue = []

    # produce a log of all the time-bound side effects
    @event_log = []
  end

  def enqueue_unit(unit)
    @pending_build_queue << unit
  end

  def minerals_at_time(time)
    @minerals.at_time(time)
  end

  def time_at_minerals(minerals)
    @minerals.at_resource(minerals)
  end

  def miners_at_time(time)
    @minerals.harvesters_at_time(time)
  end

  def gas_at_time(time)
    @gas.at_time(time)
  end

  def time_at_gas(gas)
    @gas.at_resource(gas)
  end

  def refiners_at_time(time)
    @gas.harvesters_at_time(time)
  end

  def supplies_total_at_time(time)
    @supply.total_at_time(time)
  end

  def supplies_used_at_time(time)
    @supply.used_at_time(time)
  end

  def time_at_supplies(supply)
    @supply.at_resource(supply)
  end

  def get_log_string
    @event_log.sort { |a,b| a[0] <=> b[0] }.map { |event| "#{Time.at(event[0]).strftime("%M:%S")}: M: #{"%4d" % minerals_at_time(event[0])} G: #{"%4d" % gas_at_time(event[0])} #{supplies_used_at_time(event[0])}/#{supplies_total_at_time(event[0])} #{event[1]} #{event[2]}"}.join("\n")
  end

  # TODO: make this method less stateful (i.e. it should be possible to
  # tweak the build queue and then rerun calculate instead of having to
  # start from scratch with a new build order.)
  def calculate
    puts "[INFO] Starting build order calculation." if COPIOUS_DEBUGGING
    build_order = []

    @pending_build_queue.each do |unit|
      puts "[INFO] Building #{unit['name']}." if COPIOUS_DEBUGGING

      # 1. verify dependencies
      verify_dependencies(unit, @built)

      # 2. determine when necessary resources are available
      start_time = earliest_start_for(unit)
      puts "[INFO] 2. Earliest starting time for #{unit['id']} is #{start_time} seconds." if COPIOUS_DEBUGGING
      log_event([start_time, 'producer_tasked', builder_for_unit(unit, start_time).unit['name']])

      # 3. mark resources consumed
      consume_minerals(start_time, unit) if unit.has_key?('minerals') && unit['minerals'] > 0
      consume_gas(start_time, unit)      if unit.has_key?('gas') && unit['gas'] > 0
      consume_supply(start_time, unit)   if unit['category'] == 'unit'

      # 4. tweak start time based on what's doing the building
      start_time = construct_building(start_time, unit, @minerals)

      # 5. set the building time only AFTER the building constraints have run
      finish_time = start_time + unit['time']
      puts "[INFO] 5. #{unit['name']} (#{unit['id']}) will be finished at #{finish_time} seconds." if COPIOUS_DEBUGGING

      # 6. update the various queues based on type of unit to be built
      update_queues_for_unit(unit, finish_time)

      # 7. put the unit to be built on a builder's build queue
      enqueue_build(unit, start_time, finish_time)

      # 8. add new producers to the builder queue.
      add_producer(unit, start_time, @producer_list) if unit['types'].include?('producer')

      # 9. add the unit to the build order's inventory
      update_inventory(unit, finish_time, @built)

      # 10. add the unit to the build order
      build_order << BuildEvent.new(unit,
                                    start_time,
                                    finish_time,
                                    minerals_at_time(finish_time),
                                    gas_at_time(finish_time),
                                    supplies_used_at_time(finish_time),
                                    supplies_total_at_time(finish_time))
    end

    build_order.sort { |a,b| a.start_time <=> b.start_time }
  end

  # Units can only start building if:
  #  - their dependencies are available.
  #  - enough minerals have accrued.
  #  - enough gas has accrued.
  def earliest_start_for(unit)
    builder = earliest_builder_for_unit(unit)
    puts "[DEBUG] #{unit['name']}: Builder is #{builder.unit['name']}." if COPIOUS_DEBUGGING

    raise(DependencyError, "No builder for #{unit['name']} is defined in source data.") unless builder

    if builder.queue.size > 0
      puts "[DEBUG] #{unit['name']}: Builder has queue of size #{builder.queue.size}." if COPIOUS_DEBUGGING
      builder_start_time = builder.queue.last.finish_time
    else
      puts "[DEBUG] #{unit['id']}: Builder is first available at #{builder.start_time} seconds." if COPIOUS_DEBUGGING
      builder_start_time = builder.start_time
    end
    puts "[DEBUG] #{unit['name']}: Earliest #{builder.unit['name']} is available at #{builder_start_time} seconds." if COPIOUS_DEBUGGING

    minerals_satisfied     = time_at_minerals(unit['minerals'])
    puts "[DEBUG] #{unit['name']}: #{unit['minerals']} minerals will be available at #{minerals_satisfied}." if COPIOUS_DEBUGGING

    gas_satisfied          = time_at_gas(unit['gas'])
    puts "[DEBUG] #{unit['name']}: #{unit['gas']} gas will be available at #{gas_satisfied}." if COPIOUS_DEBUGGING

    if unit['category'] == 'unit'
      supplies_satisfied   = time_at_supplies(unit['supplies'])
      puts "[DEBUG] #{unit['name']}: #{unit['supplies']} supplies will be available at #{supplies_satisfied}." if COPIOUS_DEBUGGING
    else
      supplies_satisfied   = 0
      puts "[DEBUG] #{unit['name']}: doesn't consume supply." if COPIOUS_DEBUGGING
    end

    dependencies_satisfied = time_dependencies_satisfied_for(unit)
    puts "[DEBUG] #{unit['name']}: All unit dependencies will be satisfied at #{dependencies_satisfied} seconds." if COPIOUS_DEBUGGING

    earliest_satisfied = [ builder_start_time,
                           dependencies_satisfied,
                           minerals_satisfied,
                           gas_satisfied,
                           supplies_satisfied ].max
    puts "[INFO] #{unit['name']}: Earliest time all build constraints are satisfied is #{earliest_satisfied}." if COPIOUS_DEBUGGING

    earliest_satisfied
  end

  def time_dependencies_satisfied_for(unit)
    dependency_availability = []

    unit['depends'].each do |dep_id|
      raise(DependencyError, "Can't build #{unit['name']} without #{@info.lookup(dep_id)['name']}.") unless @built.has_key?(dep_id)

      dependency_availability << @built[dep_id].map { |dependency| dependency.start_time }.min
    end

    dependency_availability.max
  end

  def minerals_consumed_at_time(time)
    @minerals.consumed_at_time(time)
  end

  def gas_consumed_at_time(time)
    @gas.consumed_at_time(time)
  end

  def dump_mineral_queue
    @minerals.dump_harvester_counts
  end
  
  def dump_gas_queue
    @gas.dump_harvester_counts
  end
  
  def dump_supply_queue
    @supply.dump_available
  end
  
  def dump_mineral_used
    @minerals.dump_used
  end
  
  def dump_gas_used
    @gas.dump_used
  end
  
  def dump_supply_used
    @supply.dump_used
  end

  def log_event(event)
    @event_log << event
  end

  private

  def verify_dependencies(unit, build)
    puts "[INFO] 1. Verifying dependencies for #{unit['name']}" if COPIOUS_DEBUGGING
    unit['depends'].each do |dep|
      unless build.has_key?(dep)
        raise DependencyError, "A #{@info.lookup(dep)['name']} is required before a #{unit['name']} can be built."
      end
    end
  end

  def consume_minerals(time, unit)
    available_minerals = @minerals.at_time(time)
    if unit['minerals'] > available_minerals
      raise(InvalidEconomyError, "The Starcraft economy does not allow deficit spending (deficit of #{unit['minerals'] - available_minerals} minerals at #{time} seconds).")
    end

    @minerals.consume(unit['minerals'], time)
  end

  def consume_gas(time, unit)
    available_gas = @gas.at_time(time)
    if unit['gas'] > gas_at_time(time)
      raise(InvalidEconomyError, "The Starcraft economy does not allow deficit spending (deficit of #{unit['gas'] - available_gas} gas at #{time} seconds).")
    end

    @gas.consume(unit['gas'], time)
  end

  def consume_supply(time, unit)
    available_supply = @supply.available_at_time(time)
    if unit['supplies'] > available_supply
      raise(DependencyError, "You require additional pylons! (#{unit['supplies']} requested, #{available_supply} available).")
    end

    @supply.consume(unit['supplies'], time)
  end

  # This method will be different for each race:
  #
  # o Terran SCVs remain occupied the entire time they're building a unit.
  # o Protoss Probes only remain busy while going to and from placing the
  #   point at which the new building will be warped in.
  # o Zerg Drones become the buildings they're building (and are marked as
  #   consumed).
  def construct_building(time, unit, resource_model)
    start_time = time

    if @info.lookup(unit['builder'])['category'] == 'unit'
      placed_time = start_time + (2 * WARP_PLACEMENT_TIME)
      resource_model.task_harvester(start_time, placed_time)

      start_time += WARP_PLACEMENT_TIME
      puts "[INFO] 4a. Adjusting build start time to #{start_time} (#{WARP_PLACEMENT_TIME} seconds) to account for builder travel time." if COPIOUS_DEBUGGING

      puts "[INFO] 4b. Builder returns to mineral line at #{placed_time} seconds." if COPIOUS_DEBUGGING
    else
      puts "[INFO] 4. #{unit['id']} is not built by a unit, not tweaking start time." if COPIOUS_DEBUGGING
    end

    start_time
  end

  def update_queues_for_unit(unit, time)
    case 
    when unit['types'].include?('harvester')
      @minerals.add_harvester(time)
      puts "[INFO] 6a. #{unit['name']} is a harvester, will be sent to mineral line at #{time}." if COPIOUS_DEBUGGING
    when unit['types'].include?('refiner')
      @minerals.remove_harvesters(time, 3)
      @gas.add_harvesters(time, 3)
      puts "[INFO] 6b. #{unit['name']} (#{unit['id']}) is a refiner, 3 harvesters will be switched from mineral to gas at #{time}." if COPIOUS_DEBUGGING
    when unit['types'].include?('supplier')
      @supply.add_capacity(time, unit['provides'])
      puts "[INFO] 6c. #{unit['name']} provides supply, will be added to supply list at #{time}." if COPIOUS_DEBUGGING
    end
  end

  def enqueue_build(unit, start_time, finish_time)
    build_queue = builder_for_unit(unit, start_time)
    if build_queue.unit['category'] == 'unit'
      build_queue.queue << Event.new(unit, start_time - WARP_PLACEMENT_TIME, start_time + WARP_PLACEMENT_TIME)
      puts "[INFO] 7. #{unit['name']} will have its warp point set at #{start_time}." if COPIOUS_DEBUGGING
    else
      build_queue.queue << Event.new(unit, start_time, finish_time)
      puts "[INFO] 7b. #{unit['name']} will be added to its builder's queue to build from #{start_time} to #{finish_time} seconds." if COPIOUS_DEBUGGING
    end
    log_event([start_time, 'unit_started', unit['name']])
    log_event([finish_time, 'unit_available', unit['name']])
  end

  def add_producer(unit, time, producer_list)
    producer_list[unit['id']] += [Producer.new(unit, time)]
    log_event([time, 'producer_available', unit['name']])
  end

  def update_inventory(unit, time, built_list)
    built_list[unit['id']] += [Built.new(unit, time)]
  end

  def earliest_builder_for_unit(unit)
    @producer_list[unit['builder']].min { |a,b| a.start_time <=> b.start_time }
  end

  def builder_for_unit(unit, start_time)
    available_producers = @producer_list[unit['builder']].select { |p| p.start_time <= start_time }
    available_producers.min { |a,b| (a.queue.size == 0 ? 0 : a.queue.last.finish_time) <=> (b.queue.size == 0 ? 0 : b.queue.last.finish_time) }
  end
end