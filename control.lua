require "util"

function on_init()
  global.trains = {}
end

function on_tick()
  for i = #global.trains, 1, -1 do
    local train = global.trains[i]

    -- Do we still have control of the train?
    if not is_manual_driven(train) then
      table.remove(global.trains, i)
      return
    end

    -- Already stoppd
    train = train.train
    if train.speed <= 0 then return end

    -- Look for red signal
    local signal = get_next_signal(train)
    if not signal then return end
    if not (signal.type == "rail-signal" or signal.type == "rail-chain-signal") then return end
    if signal.signal_state == defines.signal_state.open then return end

    -- Wait for the train to reach the red signal
    local carraige = train.front_stock
    if train.speed < 1 then
      carriage = train.back_stock
    end
    local distance = util.distance(signal.position, carriage.position)

    -- Stop the train
    if distance < train.speed + 4 then
      train.speed = 0
    end
  end
end

function on_train_changed_state(event)
  if event.train and event.train.state == defines.train_state.manual_mode then
    start_control(train)
  end
end

function on_player_driving_changed_state(event)
  local player = game.get_player(event.player_index)
  if not player or not player.driving then return end
  if event.entity and event.entity.valid and event.entity.train and event.entity.train.manual_mode then
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

  -- Signal is attached to the end of the segment
  local signal = rail.get_rail_segment_entity(rail_direction, false)
  if signal then return signal end

  -- Signal is attached to the beginning of the next segment
  rail, rail_direction = rail.get_rail_segment_end(rail_direction)
  local next_rail = rail.get_connected_rail{
    rail_direction = rail_direction,
    rail_connection_direction = defines.rail_connection_direction.straight
  } or rail.get_connected_rail{
    rail_direction = rail_direction,
    rail_connection_direction = defines.rail_connection_direction.left
  } or rail.get_connected_rail{
    rail_direction = rail_direction,
    rail_connection_direction = defines.rail_connection_direction.right
  }
  if not next_rail then return end

  return next_rail.get_rail_segment_entity(rail_direction, true)
    or next_rail.get_rail_segment_entity(1-rail_direction, true)
end

function start_control(train)
  -- Add to list of controlled trains
  table.insert(global.trains, {
    train = train,
    driver = get_driver(train),
  })
end

script.on_init(on_init)
script.on_event(defines.events.on_tick, on_tick)
script.on_event(defines.events.on_train_changed_state, on_train_changed_state)
script.on_event(defines.events.on_player_driving_changed_state, on_player_driving_changed_state)
