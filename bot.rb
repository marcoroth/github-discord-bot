require 'discordrb'
require 'octokit'

if ENV['DISCORD_BOT_TOKEN']
  bot = Discordrb::Bot.new(token: ENV['DISCORD_BOT_TOKEN'])
else
  raise 'Please provide a TOKEN for your Discord bot'
end

if ENV['GITHUB_ACCESS_TOKEN']
  client = Octokit::Client.new(access_token: ENV['GITHUB_ACCESS_TOKEN'])
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
    event.message.content.scan(/#{prefix}#\d+/).each do |reference|
      _, number = reference.split('#')

      begin
        gh_repo = client.repo repo
        data = gh_repo.rels[:issues].get(uri: { number: number }).data

        title = data[:title]
        user = data[:user][:login]
        url = data[:html_url]

        type = url.include?('pull') ? 'PR' : 'Issue'

        response = "`#{reference}` - #{type} by @#{user}: \"#{title}\" \n[#{url}]"
      rescue Octokit::NotFound => e
        response = "`#{reference}` isn't an issue or pull request in `#{repo}`"
      rescue StandardError => e
        response = "https://github.com/#{repo}/issues/#{number}"
      end

      event.respond(response)
    end
  end
end

bot.run
