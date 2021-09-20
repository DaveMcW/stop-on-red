require "util"

-- Constant tables
-- Indexing a constant table is faster than creating a new one
local RAIL_STRAIGHT = {
  [defines.rail_direction.front] = {
    rail_direction = defines.rail_direction.front,
    rail_connection_direction = defines.rail_connection_direction.straight,
  },
  [defines.rail_direction.back] = {
    rail_direction = defines.rail_direction.back,
    rail_connection_direction = defines.rail_connection_direction.straight,
  },
}
local RAIL_RIGHT = {
  [defines.rail_direction.front] = {
    rail_direction = defines.rail_direction.front,
    rail_connection_direction = defines.rail_connection_direction.right,
  },
  [defines.rail_direction.back] = {
    rail_direction = defines.rail_direction.back,
    rail_connection_direction = defines.rail_connection_direction.right,
  },
}
local RAIL_LEFT = {
  [defines.rail_direction.front] = {
    rail_direction = defines.rail_direction.front,
    rail_connection_direction = defines.rail_connection_direction.left,
  },
  [defines.rail_direction.back] = {
    rail_direction = defines.rail_direction.back,
    rail_connection_direction = defines.rail_connection_direction.left,
  },
}

function on_init()
  global.trains = {}
end

function on_tick()
  for i = #global.trains, 1, -1 do
    local train = global.trains[i]

    -- Do we still have control of the train?
    if is_manual_driven(train) then

      -- Already stopped
      train = train.train
      if train.speed == 0 then return end

      -- No protection while reversing a one-way train
      if train.speed < 0
      and train.front_stock.speed < 0
      and train.back_stock.speed < 0 then
        return
      end

      -- Look for red signal
      local signal = get_next_signal(train)
      if not signal then return end

      -- rendering.draw_circle{
      --   color = {0, 1, 0},
      --   radius = 1,
      --   width = 10,
      --   target = signal,
      --   surface = signal.surface,
      --   time_to_live = 2,
      -- }

      if not (signal.type == "rail-signal" or signal.type == "rail-chain-signal") then return end
      if signal.signal_state == defines.signal_state.open then return end

      -- Wait for the train to reach the red signal
      local carriage = train.front_stock
      if train.speed < 0 then
        carriage = train.back_stock
      end
      local distance = util.distance(signal.position, carriage.position)

      -- Stop the train
      if distance < math.abs(train.speed) + 4 then
        train.speed = 0
      end

    else
      -- Lost control
      table.remove(global.trains, i)
    end
  end
end

function on_train_changed(event)
  if event.train and event.train.valid and event.train.state == defines.train_state.manual_control then
    start_control(event.train)
  end
end

function on_player_driving_changed_state(event)
  local player = game.get_player(event.player_index)
  if not player or not player.driving then return end
  if event.entity and event.entity.valid and event.entity.train then
    start_control(event.entity.train)
  end
end

function is_manual_driven(train)
  if not train.train then return false end
  if not train.train.valid then return false end
  if not train.train.manual_mode then return false end

  -- Try to find a new driver
  if not train.driver or not train.driver.valid or not train.driver.driving then
    train.driver = get_driver(train.train)
  end

  return train.driver and train.driver.valid
end

function get_driver(train)
  for _, carriage in pairs(train.carriages) do
    local driver = carriage.get_driver()
    if driver and driver.valid then
      return driver
    end
  end
end

function get_next_signal(train)
  local rail = train.front_rail
  local rail_direction = train.rail_direction_from_front_rail
  local reverse = false
  if train.speed < 0 then
    rail = train.back_rail
    rail_direction = 1 - train.rail_direction_from_back_rail
    if train.back_stock.speed < 0 then
      reverse = true
    end
  end

  -- Signal is attached to the end of the segment
  local signal = rail.get_rail_segment_entity(rail_direction, reverse)
  if signal then return signal end

  -- Signal is attached to the beginning of the next segment
  rail, rail_direction = rail.get_rail_segment_end(rail_direction)
  local next_rail = rail.get_connected_rail(RAIL_STRAIGHT[rail_direction])
    or rail.get_connected_rail(RAIL_LEFT[rail_direction])
    or rail.get_connected_rail(RAIL_RIGHT[rail_direction])

  if not next_rail then return end

  -- rendering.draw_circle{
  --   color = {1, 0, 0},
  --   radius = 1,
  --   width = 10,
  --   target = next_rail,
  --   surface = next_rail.surface,
  --   time_to_live = 2,
  -- }

  return next_rail.get_rail_segment_entity(rail_direction, not reverse)
    or next_rail.get_rail_segment_entity(1-rail_direction, not reverse)
end

function start_control(train)
  -- Are we already controlling it?
  for i = 1, #global.trains do
    local old_train = global.trains[i].train
    if old_train and old_train.valid and old_train.id == train.id then return end
  end
  -- Add to list of controlled trains
  table.insert(global.trains, {
    train = train,
    driver = get_driver(train),
  })
end

script.on_init(on_init)
script.on_event(defines.events.on_tick, on_tick)
script.on_event(defines.events.on_train_created, on_train_changed)
script.on_event(defines.events.on_train_changed_state, on_train_changed)
script.on_event(defines.events.on_player_driving_changed_state, on_player_driving_changed_state)
