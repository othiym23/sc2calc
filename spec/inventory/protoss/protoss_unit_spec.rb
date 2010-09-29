require 'lib/inventory'

describe RacialInventory do
  describe "when working with the Protoss" do
    describe "when using Probes" do
      before :all do
        @protoss = RacialInventory.new('protoss', File.join(File.dirname(__FILE__), '../../../data/sc2.yml'))
      end

      it "should find the unit by its id (pup)" do
        @protoss.lookup('pup').should_not be_nil
      end

      it "should have the correct name" do
        @protoss.lookup('pup')['name'].should == 'Probe'
      end

      it "should produce the correct dependency list" do
        @protoss.dependency_queue('pup').should == ['pbn', 'pup']
      end
    end

    describe "when using Zealots" do
      before :all do
        @protoss = RacialInventory.new('protoss', File.join(File.dirname(__FILE__), '../../../data/sc2.yml'))
      end

      it "should find the unit by its id (puz)" do
        @protoss.lookup('puz').should_not be_nil
      end

      it "should have the correct name" do
        @protoss.lookup('puz')['name'].should == 'Zealot'
      end

      it "should produce the correct dependency list" do
        @protoss.dependency_queue('puz').should == ['pbn', 'pup', 'pbe', 'pbg', 'puz']
      end
    end

    describe "when using Stalkers" do
      before :all do
        @protoss = RacialInventory.new('protoss', File.join(File.dirname(__FILE__), '../../../data/sc2.yml'))
      end

      it "should find the unit by its id (pus)" do
        @protoss.lookup('pus').should_not be_nil
      end

      it "should have the correct name" do
        @protoss.lookup('pus')['name'].should == 'Stalker'
      end

      it "should produce the correct dependency list" do
        @protoss.dependency_queue('pus').should == ['pbn', 'pup', 'pbe', 'pbg', 'pby', 'pus']
      end
    end
  end
end