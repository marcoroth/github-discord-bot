# frozen_string_literal: true

def save_mapping(id, shortcut, repo)
  @redis.hset("#{@redis_prefix}:#{id}:mappings", shortcut, repo)
end

def delete_mapping(id, shortcut)
  @redis.hdel("#{@redis_prefix}:#{id}:mappings", shortcut)
end

def server_mappings(event)
  return [] unless event.server

  @redis.hgetall("#{@redis_prefix}:#{event.server.id}:mappings")
end

def roles(id)
  @redis.smembers("#{@redis_prefix}:#{id}:roles")
end

def role?(id, roles)
  roles(id).each do |role|
    return true if roles.include? role
  end

  false
end

def action_allowed?(event)
  event.server && role?(event.server.id, event.user.roles.map(&:name))
end
