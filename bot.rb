# frozen_string_literal: true

require 'discordrb'
require 'octokit'
require 'redis'
require './helpers'

raise 'Please provide a DISCORD_BOT_TOKEN for your Discord bot' unless ENV['DISCORD_BOT_TOKEN']

bot = Discordrb::Bot.new(token: ENV['DISCORD_BOT_TOKEN'])
client = Octokit::Client.new(access_token: ENV['GITHUB_ACCESS_TOKEN'])

@redis = ENV['REDIS_URL'] ? Redis.new(url: ENV['REDIS_URL']) : Redis.new
@redis_prefix = 'github-bot'

puts "This bot's invite URL is #{bot.invite_url}."
puts 'Click on it to invite it to your server.'

bot.ready do
  bot.servers.each_key do |key, _server|
    key = "#{@redis_prefix}:#{key}"

    next if @redis.get(key)

    @redis.set(key, '1')
    @redis.sadd("#{key}:roles", 'admin')
    @redis.sadd("#{key}:roles", 'contributor')
    @redis.sadd("#{key}:roles", 'moderator')
  end
end

bot.reaction_add do |event|
  event.message.delete if event.message.author == bot.bot_user && action_allowed?(event)
end

bot.mention(contains: 'add') do |event|
  if action_allowed?(event)
    matches = event.text.scan(%r{add (.+) (.+/.+)}).first

    if matches&.length == 2
      shortcut, repo = matches

      save_mapping(event.server.id, shortcut, repo)

      event.respond("Added mapping for shortcut `#{shortcut}` and repo `#{repo}`. \nTry `#{shortcut}#<number>`")
    else
      event.respond "Usage: `add <shortcut> <repo>` \nExample: `add MR marcoroth/github-bot`"
    end
  end
end

bot.mention(contains: 'remove') do |event|
  if action_allowed?(event)
    matches = event.text.scan(/remove (.+)/).first

    if matches&.length == 1
      shortcut = matches[0]
      delete_mapping(event.server.id, shortcut)

      event.respond("Removed mapping for shortcut `#{shortcut}`")
    else
      event.respond "Usage: `remove <shortcut>` \nExample: `remove MR`"
    end
  end
end

bot.mention(contains: 'list') do |event|
  if action_allowed?(event)
    server_mappings(event).each do |key, repo|
      event << "`#{key}` => `#{repo}`"
    end
  end
end

regex = /((.+)#(\d+))/

bot.message(contains: regex) do |event|
  unless event.channel.private?
    mappings = server_mappings(event)

    if mappings.any?
      prefixes = mappings.keys.join('|')
      mappings_regex = /((#{prefixes})#(\d+))/

      event.text.scan(mappings_regex).each do |reference, prefix, number|
        repo_name = mappings[prefix]

        begin
          repo = client.repo(repo_name)
          data = repo.rels[:issues].get(uri: { number: number }).data

          title = data[:title]
          user = data[:user][:login]
          url = data[:html_url]

          type = url.include?('pull') ? 'PR' : 'Issue'

          response = "`#{reference}` - #{type} by @#{user}: \"#{title}\" \n[#{url}]"
        rescue Octokit::NotFound
          response = "`#{reference}` isn't an issue or pull request in `#{repo_name}`"
        rescue StandardError
          response = "https://github.com/#{repo_name}/issues/#{number}"
        end

        event.respond(response)
      end
    end
  end
end

bot.run
