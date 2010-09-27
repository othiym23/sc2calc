require 'lib/inventory'

describe RacialInventory do
  before :each do
    @protoss = RacialInventory.new('protoss', File.join(File.dirname(__FILE__), '../data/sc2.yml'))
    @terran  = RacialInventory.new('terran',  File.join(File.dirname(__FILE__), '../data/sc2.yml'))
    @zerg    = RacialInventory.new('zerg',    File.join(File.dirname(__FILE__), '../data/sc2.yml'))
    @all_races = [@protoss, @terran, @zerg]
  end

  describe "for each unit" do
    def ensure_dependency(race_list, attribute)
      race_list.each do |race|
        race.all_units.each do |unit_id|
          unit = race.lookup(unit_id)
          test_string = unit['id'] + (unit[attribute].nil? ? ' FAIL' : ' SUCCEED')
          test_string.should == "#{unit['id']} SUCCEED"
        end
      end
    end

    def ensure_costed_dependency(race_list, attribute)
      race_list.each do |race|
        race.all_units.each do |unit_id|
          unit = race.lookup(unit_id)

          if ['upgrade', 'unit', 'building'].include?(unit['category'])
            test_string = unit['id'] + (unit[attribute].nil? ? ' FAIL' : ' SUCCEED')
            test_string.should == "#{unit['id']} SUCCEED"
          end
        end
      end
    end

    def ensure_unit_dependency(race_list, attribute)
      race_list.each do |race|
        race.all_units.each do |unit_id|
          unit = race.lookup(unit_id)

          if 'unit' == unit['category']
            test_string = unit['id'] + (unit[attribute].nil? ? ' FAIL' : ' SUCCEED')
            test_string.should == "#{unit['id']} SUCCEED"
          end
        end
      end
    end

    it "requires the unit to have a name" do
      ensure_dependency(@all_races, 'name')
    end

    it "requires the unit to have a category" do
      ensure_dependency(@all_races, 'category')
    end

    it "requires the unit to have a mineral cost" do
      ensure_costed_dependency(@all_races, 'minerals')
    end

    it "requires the unit to have a gas cost" do
      ensure_costed_dependency(@all_races, 'gas')
    end

    it "requires the unit to have a supply cost" do
      ensure_unit_dependency(@all_races, 'supplies')
    end

    it "requires the unit to have a build time" do
      ensure_costed_dependency(@all_races, 'time')
    end

    it "requires the unit to have a builder" do
      ensure_costed_dependency(@all_races, 'builder')
    end

    it "requires the unit to have a dependency list" do
      ensure_dependency(@all_races, 'depends')
    end
  end

  describe "for all races" do
    it "should have ability cost types of energy, gas, minerals passive, time and units" do
      inventory = @all_races.map { |race| race.all_units.map { |unit_id| race.lookup(unit_id) } }.flatten
      costs = inventory.select { |unit| unit['category'] == 'ability' }.map { |unit| unit['costs'] }.flatten
      cost_types = costs.map { |cost| cost['type'] }

      cost_types.sort.uniq.should  == ['energy', 'gas', 'minerals', 'passive', 'time', 'units']
    end
  end

  describe "for all suppliers" do
    it "should provide more than 0 supply" do
      inventory = @all_races.map { |race| race.all_units.map { |unit_id| race.lookup(unit_id) } }.flatten
      units = inventory.select { |unit| unit['category'] == 'unit' }
      suppliers = units.select { |unit| unit['types'].include? 'supplier' }
      suppliers.detect { |supplier| !(supplier.has_key?('provides') && supplier['provides'] > 0) }.should be_nil
    end
  end
end