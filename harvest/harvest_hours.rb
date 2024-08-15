require "uri"
require "json"

SECONDS_IN_A_DAY = 86400

# TODO: I clearly copy-pasted this from StackOverflow. Typically I would
# include the URL to that. I should add that if I re-find it.
def end_of_week(date)
  # TODO: I think this could just be `days_to_sunday = date.wday % 7`
  today_is_sunday = date.wday == 0
  days_to_sunday = today_is_sunday ? 0 : 7 - date.wday
  date + (days_to_sunday * SECONDS_IN_A_DAY)
end

def beginning_of_week(date)
  # Subtracting 6 days to get us back to Monday. If I were to instead subtract
  # 7, then that would get us back to Sunday which, as an inclusive range,
  # would double count on hours recorded on a Sunday from one week to the next.
  end_of_week(date) - (6 * SECONDS_IN_A_DAY)
end

from = beginning_of_week(Time.now).strftime("%Y-%m-%d")
to = end_of_week(Time.now).strftime("%Y-%m-%d")

entries_api_url = "https://api.harvestapp.com/v2/time_entries"
uri = URI(entries_api_url)
query = query = URI.encode_www_form({from: from, to: to})
uri.query = query

def get_required_env_var(key)
  value = ENV[key]

  return value unless value.nil? || value.empty?

  puts "The '#{key}' env var is required to run this script."
  puts "Add it to your environment, e.g. via a .envrc file."

  exit 1
end

harvest_account_id = get_required_env_var('HARVEST_ACCOUNT_ID')
harvest_api_key = get_required_env_var('HARVEST_API_KEY')

curl = <<-HARVEST_REQUEST
  curl -s \
    -H 'Harvest-Account-ID: #{harvest_account_id}'\
    -H 'Authorization: Bearer #{harvest_api_key}'\
    -H 'User-Agent: Harvest API' \
    "#{uri}"
HARVEST_REQUEST

result = `#{curl}`

entries = JSON.parse(result)["time_entries"]
hours_per_project =
  entries
    .map { |e| [e["hours"], e["task"]["name"]] }
    .group_by { |tuple| tuple.last }
    .map { |k, v| [k, v.sum { |tuple| tuple.first }] }

puts ""
puts "---------------------------------"
puts "|       Hours Per Project       |"
puts "---------------------------------"
hours_per_project.each do |project_name, hours|
  hours_decimal = hours.to_f.round(2)
  hours_digit, percentage_minutes = hours.to_f.divmod(1)
  minutes = (60 * percentage_minutes).to_i
  padded_minutes = minutes.to_s.rjust(2, "0")
  hours_standard = "#{hours_digit}:#{padded_minutes}"
  puts "> #{project_name}: #{hours_decimal} / #{hours_standard} hours"
end
puts "---------------------------------"
