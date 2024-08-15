require "uri"
require "json"
require "date"
require 'optparse'

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

def beginning_of_month(current_date = Date.today)
  Date.new(current_date.year, current_date.month, 1)
end

def end_of_month(current_date = Date.today)
  Date.new(current_date.year, current_date.month, -1)
end

# otherwise default to current week range
current_week_from = beginning_of_week(Time.now).strftime("%Y-%m-%d")
current_week_to = end_of_week(Time.now).strftime("%Y-%m-%d")

default_options = {
  client: :ALL,
  from: current_week_from,
  to: current_week_to
}

options = default_options
OptionParser.new do |opt|
  opt.on('--current-month') do |o|
    # if current month is set, set the month range
    from = beginning_of_month.strftime("%Y-%m-%d")
    to = end_of_month.strftime("%Y-%m-%d")
    options[:from] = from
    options[:to] = to
  end
  opt.on('--previous-month') do |o|
    # if previous month is set, set the month range
    from = beginning_of_month(Date.today << 1).strftime("%Y-%m-%d")
    to = end_of_month(Date.today << 1).strftime("%Y-%m-%d")
    options[:from] = from
    options[:to] = to
  end
  opt.on('--months-ago NUM', Integer) do |o|
    offset = Integer(o)
    from = beginning_of_month(Date.today << offset).strftime("%Y-%m-%d")
    to = end_of_month(Date.today << offset).strftime("%Y-%m-%d")
    options[:from] = from
    options[:to] = to
  end
  opt.on('--client CLIENT_NAME') { |o| options[:client] = o if !!o }
end.parse!

entries_api_url = "https://api.harvestapp.com/v2/time_entries"
uri = URI(entries_api_url)
query = query = URI.encode_www_form({from: options[:from], to: options[:to]})
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

# First, organize the entries by task-name/ID
grouped_by_task = entries.group_by { |hash| hash["task"]["name"] }

if options[:client] != :ALL
  grouped_by_task = grouped_by_task.filter { |client_name,entries| client_name == options[:client] }

  if grouped_by_task.empty?
    raise "error: all entries were filtered out by client '#{options[:client]}'."
  end
end

#
# Second, sort those collections by date asc
grouped_by_task.each do |name, group|
  grouped_by_task[name] = group.sort_by { |hash| DateTime.parse(hash["spent_date"]) }
end

#
# Third, grab the bits of data as described above
grouped_by_task.each do |name, group|
  grouped_by_task[name] = group.map do |entry|
    {
      date: Date.parse(entry["spent_date"]).strftime("%Y-%m-%d"),
      time: entry["hours"],
      notes: entry["notes"],
    }
  end
end

#
# Fourth, print it out
puts grouped_by_task.to_json
