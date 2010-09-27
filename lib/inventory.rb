require 'yaml'

class RacialInventory
  def initialize(race, yaml_path)
    @race = race
    @source_data = load_yaml(yaml_path)
    @inventory = build_inventory(@race, @source_data)
  end

  def dependency_queue(unit_id)
    if current_unit = @inventory[unit_id]
      dep_helper([unit_id], [])
    else
      []
    end
  end

  def extract_shorts
    letters = []
    @inventory.values.sort { |a,b| a['name'] <=> b['name'] }.each do |unit|
      if unit.has_key?('short')
        if letters.include?(unit['short'])
          puts "[DEBUG] '#{unit['short']}' is already in short set for race #{race}"
        else
          letters << unit['short'].to_s
        end
      else
        puts "[DEBUG] #{unit['name']} has no short code"
      end
    end

    keyboard_rows = "1234567890|QWERTYUIOP|ASDFGHJKL|ZXCVBNM|qwertyuiop|asdfghjkl|zxcvbnm".split(//)
    (keyboard_rows - letters).join('')
  end

  def lookup(unit_id)
    @inventory[unit_id]
  end

  def all_units
    @inventory.keys
  end

  private

  def dep_helper(dependency_list, stack)
    dependency_list.each do |unit_id|
      unit = @inventory[unit_id] || puts("[ERROR] no unit for id #{unit_id}")
      dep_helper(unit['depends'], stack) if unit.has_key?('depends')
      stack.push(unit_id) unless stack.include?(unit_id)
    end

    stack
  end

  def build_inventory(race, source_data)
    inventory = {}

    if raw_inventory = source_data[race]
      raw_inventory.values.compact.each do |category|
        category.each do |item|
          if item.has_key?('id')
            unless inventory[item['id']]
              inventory[item['id']] = item
            else
              puts "[ERROR] #{item['id']} is already defined."
              puts "[DEBUG] existing definition:\n#{inventory[item['id']].to_yaml}"
              puts "[DEBUG] new definition:\n#{item.to_yaml}"
            end
          else
            puts "[WARN] #{item['name']} has no ID"
          end
        end
      end
    end

    inventory
  end

  def load_yaml(path)
    YAML.load_file(path) || puts("[ERROR] unable to load YAML source.")
  end
end
