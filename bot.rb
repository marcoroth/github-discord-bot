require 'discordrb'
require 'octokit'

if ENV['TOKEN']
  bot = Discordrb::Bot.new(token: ENV['TOKEN'])
else
  raise 'Please provide a TOKEN for your Discord bot'
end

if ENV['ACCESS_TOKEN']
  client = Octokit::Client.new(access_token: ENV['ACCESS_TOKEN'])
else
  client = Octokit::Client.new
end

puts "This bot's invite URL is #{bot.invite_url}."
puts 'Click on it to invite it to your server.'

MAPPINGS = {
  'SR': 'hopsoft/stimulus_reflex',
  'CR': 'hopsoft/cable_ready',
  'Expo': 'hopsoft/stimulus_reflex_expo'
}

MAPPINGS.each do |prefix, repo|
  bot.message(contains: "#{prefix}#") do |event|
    message = event.message.content
    reference = message.match(/#{prefix}#\d+/).to_s
    _, number = reference.split('#')

    begin
      gh_repo = client.repo repo
      data = gh_repo.rels[:issues].get(uri: { number: number }).data

      title = data[:title]
      user = data[:user][:login]
      url = data[:html_url]

      type = url.include?('pull') ? 'PR' : 'Issue'

      event << "`#{reference}` - #{type} by @#{user}: \"#{title}\""
      event << "[#{url}]"
    rescue
      event.respond "https://github.com/#{repo}/issues/#{number}"
    end
  end
end

bot.run
