# This file is called when a cypress spec fails and allows for extra logging to be captured
filename = command_options.fetch('runnable_full_title', 'no title')
  .to_s
  .gsub(/[^0-9A-Za-z._-]/, '_')

# Capture the most recent log block after the last APPCLEANED marker.
log_file = Rails.root.join('log', "#{Rails.env}.log")
log_output_file = Rails.root.join('log', "#{filename}.log")
if File.exist?(log_file)
  lines = File.readlines(log_file, chomp: true).last(10_000)
  marker_index = lines.rindex { |line| line.include?('APPCLEANED') }
  lines = lines[(marker_index + 1)..] if marker_index
  File.write(log_output_file, "#{lines.join("\n")}\n")
end

# create a json debug file for server debugging
json_result = {}
json_result['error'] = command_options.fetch('error_message', 'no error message')

if defined?(ActiveRecord::Base)
  json_result['records'] =
    ActiveRecord::Base.descendants.each_with_object({}) do |record_class, records|
      begin
        records[record_class.to_s] = record_class.limit(100).map(&:attributes)
      rescue
      end
    end
end

File.write(Rails.root.join('log', "#{filename}.json"), JSON.pretty_generate(json_result))
