require 'lib/build_order'

describe BuildOrder do
  describe "when working with the Protoss" do
    before :all do
      @protoss = RacialInventory.new('protoss', File.join(File.dirname(__FILE__), '../data/sc2.yml'))
    end

    before :each do
      @build = BuildOrder.new(@protoss)
    end

    it "should start with 50 minerals" do
      @build.minerals_at_time(0).should == 50
      @build.time_at_minerals(50).should == 0
    end

    it "should harvest 80 minerals in 8 seconds" do
      @build.minerals_at_time(8).should == 80
      @build.time_at_minerals(80).should == 8
    end

    it "should accurately map time -> minerals" do
      (1..1_000).each do |tick|
        @build.time_at_minerals(@build.minerals_at_time(tick)).should == tick
      end
    end

    it "should return a time of 0 to build 0 minerals" do
      @build.time_at_minerals(0).should == 0
    end

    it "should return a time of 0 to build -1 minerals" do
      @build.time_at_minerals(-1).should == 0
    end

    it "should harvest 50 minerals in -1 time" do
      @build.minerals_at_time(-1).should == 50
    end

    it "should start with 0 gas" do
      @build.gas_at_time(0).should == 0
      @build.time_at_gas(0).should == 0
    end

    it "should harvest 0 minerals in 8 seconds" do
      @build.gas_at_time(8).should == 0
    end

    describe "when calculating a build order" do
      before :each do
        @probe = @protoss.lookup('pup')
      end

      it "should show the first Probe being ready at 0:17" do
        @build.enqueue_unit(@probe)

        build_order = @build.calculate
        build_order.size.should == 1
        build_order.first.finish_time.should == 17
      end

      it "should show 50 minerals for the first probe consumed at time 0" do
        @build.enqueue_unit(@probe)
        build_order = @build.calculate
        @build.minerals_consumed_at_time(0).should == 50
      end

      it "should show the second Probe being ready at 0:34" do
        @build.enqueue_unit(@probe)
        @build.enqueue_unit(@probe)

        build_order = @build.calculate
        build_order.size.should == 2
        @build.minerals_consumed_at_time(0).should == 50
        build_order.last.finish_time.should == 34
      end
    end

    describe "when building a Probe at start" do
      before :each do
        @probe = @protoss.lookup('pup')
        @build.enqueue_unit(@probe)
        @build_order = @build.calculate
        @build_event = @build_order.first
      end

      it "should show 50 minerals for the first probe consumed at time 0" do
        @build.minerals_consumed_at_time(0).should == 50
      end

      it "should show 0 minerals available at time 0" do
        @build.minerals_at_time(0).should == 0
      end

      it "should start building at 0:00" do
        @build_event.start_time.should == 0
      end

      it "should be ready at 0:17" do
        @build_event.finish_time.should == 17
      end

      it "should have 100 minerals available at end" do
        @build_event.mineral_at_end.should == 63
      end

      it "should have 0 gas available at end" do
        @build_event.gas_at_end.should == 0
      end

      it "should have 7 supply used at end" do
        @build_event.supply_used.should == 7
      end

      it "should have 10 supply available at end" do
        @build_event.supply_available.should == 10
      end
    end

    describe "when building a Pylon from scratch" do
      before :each do
        @pylon = @protoss.lookup('pbe')
        @build.enqueue_unit(@pylon)
        @build_order = @build.calculate
        @build_event = @build_order.first
      end

      it "should have a single event in the calculated build order" do
        @build_order.size.should == 1
      end

      it "should start building at 0:16 (14 seconds for harvesting, 2 seconds for placement)" do
        @build_event.start_time.should == 16
      end

      it "should be ready at 0:41 (25 seconds to build)" do
        @build_event.finish_time.should == 41
      end

      it "should have 100 minerals available at end" do
        @build_event.mineral_at_end.should == 100
      end

      it "should have 0 gas available at end" do
        @build_event.gas_at_end.should == 0
      end

      it "should have 6 supply used at end" do
        @build_event.supply_used.should == 6
      end

      it "should have 18 supply available at end" do
        @build_event.supply_available.should == 18
      end
    end

    describe "when building an Assimilator from scratch" do
      before :each do
        @assimilator = @protoss.lookup('pba')
        @build.enqueue_unit(@assimilator)
        @build_order = @build.calculate
        @build_event = @build_order.first
      end

      it "should have a single event in the calculated build order" do
        @build_order.size.should == 1
      end

      it "should start building at 0:09 (7 seconds for harvesting, 2 seconds for placement)" do
        @build_event.start_time.should == 9
      end

      it "should be ready at 0:39 (30 seconds to build)" do
        @build_event.finish_time.should == 39
      end

      it "should have 100 minerals available at end" do
        @build_event.mineral_at_end.should == 118
      end

      it "should have 0 gas available at end" do
        @build_event.gas_at_end.should == 0
      end

      it "should have 6 supply used at end" do
        @build_event.supply_used.should == 6
      end

      it "should have 10 supply available at end" do
        @build_event.supply_available.should == 10
      end

      it "should start producing gas" do
        @build.gas_at_time(100).should > 0
      end

      it "should switch 3 harvesters to gas production" do
        @build.miners_at_time(100).should == 3
        @build.refiners_at_time(100).should == 3
      end

      it "should take 10 seconds to harvest 30 gas" do
        (@build.time_at_gas(30) - @build_event.finish_time).should == 10
      end
    end

    describe "when trying to build a unit that's missing a builder" do
      it "should raise a DependencyError" do
        @zealot  = @protoss.lookup('puz')
        @build.enqueue_unit(@zealot)
        lambda { @build.calculate }.should raise_error(DependencyError)
      end
    end

    describe "when building with passive dependencies" do
      before :each do
        @gateway     = @protoss.lookup('pbg')
        @pylon       = @protoss.lookup('pbe')
        @stalker     = @protoss.lookup('pus')
        @core        = @protoss.lookup('pby')
        @assimilator = @protoss.lookup('pba')
      end

      it "should raise a DependencyError when a dependency isn't satisfied" do
        @build.enqueue_unit(@pylon)
        @build.enqueue_unit(@gateway)
        @build.enqueue_unit(@stalker)
        lambda { @build.calculate }.should raise_error(DependencyError)
      end

      it "should block the start of a unit build until all passive dependencies are available" do
        @build.enqueue_unit(@assimilator)
        @build.enqueue_unit(@pylon)
        @build.enqueue_unit(@gateway)
        @build.enqueue_unit(@core)
        @build.enqueue_unit(@stalker)
        @build_order = @build.calculate
        @build_order[3].start_time.should >= @build_order[2].finish_time
      end
    end

    describe "when building a Gateway and Zealot" do
      before :each do
        @gateway = @protoss.lookup('pbg')
        @pylon   = @protoss.lookup('pbe')
        @zealot  = @protoss.lookup('puz')
        @build.enqueue_unit(@pylon)
        @build.enqueue_unit(@gateway)
        @build.enqueue_unit(@zealot)
        @build_order = @build.calculate
      end

      it "shouldn't start the Gateway before the Pylon is finished" do
        @build_order[1].start_time.should >= @build_order[0].finish_time
      end

      it "shouldn't start the Zealot before the Gateway is finished" do
        @build_order[2].start_time.should >= @build_order[1].finish_time
      end

      it "should accurately reflect that a Zealot uses 2 supply" do
        (@build_order[2].supply_used - @build_order[1].supply_used).should == 2
      end

      it "should accurately map time -> minerals" do
        (125..1_000).each do |tick|
          @build.time_at_minerals(@build.minerals_at_time(tick)).should == tick
        end
      end
    end
    
    describe "when building with both minerals and gas" do
      before :each do
        @build = BuildOrder.queue_up_build(@protoss, ['pba', 'pbe', 'pbg', 'pby', 'puz', 'pus'])
      end

      it "shouldn't allow spending to go into the red" do
        lambda { @build.calculate }.should_not raise_error(InvalidEconomyError)
      end

      it "shouldn't allow the economy to be off by too great a factor" do
        @build = BuildOrder.queue_up_build(@protoss, ['pup', 'pba', 'pbe', 'pbg', 'pby', 'puz', 'pus', 'pus', 'pus'])
        lambda { @build.calculate }.should_not raise_error(InvalidEconomyError)
      end

      it "should accurately map time -> minerals" do
        @build = BuildOrder.queue_up_build(@protoss, ['pup', 'pba', 'pbe', 'pbg', 'pby', 'puz', 'pus', 'pus', 'pus'])
        lambda { @build.calculate }.should_not raise_error(InvalidEconomyError)

        (500..1_000).each do |tick|
          @build.time_at_minerals(@build.minerals_at_time(tick)).should == tick
        end
      end
    end
  end
end