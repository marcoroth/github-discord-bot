# frozen_string_literal: true

require 'discordrb'
require 'octokit'

raise 'Please provide a TOKEN for your Discord bot' unless ENV['DISCORD_BOT_TOKEN']

bot = Discordrb::Bot.new(token: ENV['DISCORD_BOT_TOKEN'])
client = Octokit::Client.new(access_token: ENV['GITHUB_ACCESS_TOKEN'])

puts "This bot's invite URL is #{bot.invite_url}."
puts 'Click on it to invite it to your server.'

MAPPINGS = {
  'SR': 'hopsoft/stimulus_reflex',
  'CR': 'hopsoft/cable_ready',
  'Expo': 'hopsoft/stimulus_reflex_expo'
}.freeze

prefixes = MAPPINGS.keys.join('|')
regex = /((#{prefixes})#(\d+))/

bot.message(contains: regex) do |event|
  event.message.content.scan(regex).each do |reference, prefix, number|
    repo_name = MAPPINGS[prefix.to_sym]

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

bot.run
