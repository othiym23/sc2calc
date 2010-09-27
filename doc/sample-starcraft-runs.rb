$:.unshift("lib/")
require 'build_order'

@protoss = RacialInventory.new('protoss', 'data/sc2.yml')
@assimilator = @protoss.lookup('pba')
@core        = @protoss.lookup('pby')
@forge       = @protoss.lookup('pbf')
@gateway     = @protoss.lookup('pbg')
@probe       = @protoss.lookup('pup')
@pylon       = @protoss.lookup('pbe')
@stalker     = @protoss.lookup('pus')
@zealot      = @protoss.lookup('puz')

@build = BuildOrder.new(@protoss)
@build.enqueue_unit(@probe)
@build.enqueue_unit(@probe)
@build.enqueue_unit(@probe)
@build.enqueue_unit(@probe)
@build.enqueue_unit(@pylon)
@build.enqueue_unit(@gateway)
@build.enqueue_unit(@zealot)
@build.enqueue_unit(@probe)
@build.enqueue_unit(@probe)
@build.enqueue_unit(@probe)
@build.enqueue_unit(@probe)
@build.enqueue_unit(@forge)
@build.enqueue_unit(@probe)
@build.enqueue_unit(@probe)
@build.enqueue_unit(@assimilator)
@build.enqueue_unit(@probe)
@build.enqueue_unit(@probe)
@build.enqueue_unit(@pylon)
@build.enqueue_unit(@assimilator)
@build.enqueue_unit(@probe)
@build.enqueue_unit(@core)
@build.enqueue_unit(@probe)
@build.enqueue_unit(@probe)
@build.enqueue_unit(@probe)
@build.enqueue_unit(@pylon)
@build.enqueue_unit(@probe)
@build.enqueue_unit(@gateway)
@build.enqueue_unit(@zealot)
@build.enqueue_unit(@stalker)
@build.enqueue_unit(@stalker)
@build.enqueue_unit(@stalker)

BuildOrderPrinter.print(@build.calculate)
puts @build.get_log_string
puts @build.dump_mineral_queue
puts @build.dump_gas_queue
puts @build.dump_supply_queue
puts @build.dump_mineral_used
puts @build.dump_gas_used
puts @build.dump_supply_used
@build.time_at_minerals(50)


# reproducibly whackadoo build order, DO NOT CHANGE
$:.unshift("lib/")
require 'build_order'
@protoss = RacialInventory.new('protoss', 'data/sc2.yml') ; nil
@build = BuildOrder.queue_up_build(@protoss, ['pba', 'pbe', 'pbg', 'pby', 'puz', 'pus', 'pus', 'pus']) ; nil

@build_order = @build.calculate ; nil
BuildOrderPrinter.print(@build_order) ; nil
puts @build.get_log_string ; nil
puts @build.dump_mineral_queue ; nil
puts @build.dump_gas_queue ; nil
puts @build.dump_supply_queue ; nil
puts @build.dump_mineral_used ; nil
puts @build.dump_gas_used ; nil
puts @build.dump_supply_used ; nil
@build.time_at_minerals(50)


# minimal case that exhibits problem -- used in unit test
$:.unshift("lib/")
require 'build_order'
@protoss = RacialInventory.new('protoss', 'data/sc2.yml') ; nil
@build = BuildOrder.queue_up_build(@protoss, ['pba', 'pbe', 'pbg', 'pby', 'puz', 'pus']) ; nil
@build_order = @build.calculate ; nil

@build.minerals_at_time(261)
@build.time_at_minerals(125)

BuildOrderPrinter.print(@build_order)
puts @build.get_log_string ; nil
puts @build.dump_mineral_queue ; nil
puts @build.dump_gas_queue ; nil
puts @build.dump_supply_queue ; nil
puts @build.dump_mineral_used ; nil
puts @build.dump_gas_used ; nil
puts @build.dump_supply_used ; nil
@build.time_at_minerals(50)

# functional
BuildOrder.queue_up_build(@protoss, ['pbe', 'pbg']).calculate
# functional
BuildOrder.queue_up_build(@protoss, ['pbe', 'pbg', 'puz']).calculate
# [INFO] 4a. 150/126 Minerals used at 147 seconds for pby updated to 150
BuildOrder.queue_up_build(@protoss, ['pbe', 'pba', 'pbg', 'pby', 'pus']).calculate
# [INFO] 4a. 150/125 Minerals used at 180 seconds for pby updated to 150
BuildOrder.queue_up_build(@protoss, ['pba', 'pbe', 'pbg', 'pby', 'puz', 'pus', 'pus', 'pus']).calculate
# [INFO] 4a. 75/70 Minerals used at 19 seconds for pba updated to 75
BuildOrder.queue_up_build(@protoss, ['pup', 'pba', 'pbe', 'pbg', 'pby', 'puz', 'pus', 'pus', 'pus']).calculate
# [INFO] 4a. 100/70 Minerals used at 19 seconds for pbe updated to 100
BuildOrder.queue_up_build(@protoss, ['pup', 'pbe', 'pbg', 'pby', 'puz', 'pba', 'pus', 'pus', 'pus']).calculate
# [INFO] 4a. 50/37 Minerals used at 34 seconds for pup updated to 50
BuildOrder.queue_up_build(@protoss, ['pup', 'pup', 'pup', 'pbe', 'pup', 'pup', 'pup', 'pup', 'pbg', 'pbe', 'pba', 'pby', 'puz', 'pus', 'pus', 'pus']).calculate
@build = BuildOrder.queue_up_build(@protoss, ['pup', 'pup', 'pup', 'pbe', 'pup', 'pup', 'pup', 'pup', 'pbg', 'pbe', 'pba', 'pby', 'puz', 'pus', 'pus', 'pus']) ; nil
# build order taken from SC Assistant
@build = BuildOrder.queue_up_build(@protoss, ['pup', 'pup', 'pup', 'pup', 'pbe', 'pup', 'pup', 'pup', 'pbg', 'pup', 'pup', 'pup', 'pba', 'pup', 'pup', 'pbe', 'pup', 'pup', 'pby', 'pup', 'pup', 'pba', 'pup', 'pbg', 'pus', 'pup', 'pbe', 'pbe', 'pup', 'pvs', 'pup', 'pus', 'pup', 'pus', 'pup', 'puz', 'pup', 'puv', 'puz', 'pup', 'pup', 'pbe', 'puv'])

$:.unshift("lib/")
require 'build_order'
@protoss = RacialInventory.new('protoss', 'data/sc2.yml') ; nil
@build = BuildOrder.queue_up_build(@protoss, ['pup', 'pup', 'pup', 'pbe', 'pup', 'pup', 'pup', 'pup', 'pbg', 'pba', 'pby', 'pbe', 'puz', 'pus', 'pus', 'pus']) ; nil
@build_order = @build.calculate ; nil
BuildOrderPrinter.print(@build_order) ; nil
(1..450).each { |tick| puts "#{tick} M: #{@build.minerals_at_time(tick)} G: #{@build.gas_at_time(tick)}" }

puts @build.get_log_string ; nil
puts @build.dump_mineral_queue ; nil
puts @build.dump_gas_queue ; nil
puts @build.dump_supply_queue ; nil
puts @build.dump_mineral_used ; nil
puts @build.dump_gas_used ; nil
puts @build.dump_supply_used ; nil
