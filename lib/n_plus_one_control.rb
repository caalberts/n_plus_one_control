# frozen_string_literal: true

require "n_plus_one_control/version"
require "n_plus_one_control/executor"

# RSpec and Minitest matchers to prevent N+1 queries problem.
module NPlusOneControl
  # Used to extract a table name from a query
  EXTRACT_TABLE_RXP = /(insert into|update|delete from|from) ['"](\S+)['"]/i.freeze

  # Used to convert a query part extracted by the regexp above to the corresponding
  # human-friendly type
  QUERY_PART_TO_TYPE = {
    "insert into" => "INSERT",
    "update" => "UPDATE",
    "delete from" => "DELETE",
    "from" => "SELECT"
  }.freeze

  class << self
    attr_accessor :default_scale_factors, :verbose, :show_table_stats, :ignore, :event,
                  :backtrace_cleaner

    def failure_message(queries) # rubocop:disable Metrics/MethodLength
      msg = ["Expected to make the same number of queries, but got:\n"]
      queries.each do |(scale, data)|
        msg << "  #{data.size} for N=#{scale}\n"
      end

      msg.concat(table_usage_stats(queries.map(&:last))) if show_table_stats

      if verbose
        queries.each do |(scale, data)|
          msg << "Queries for N=#{scale}\n"
          msg << data.map { |sql| "  #{sql}\n" }.join.to_s
        end
      end

      msg.join
    end

    def table_usage_stats(runs) # rubocop:disable Metrics/MethodLength
      msg = ["Unmatched query numbers by tables:\n"]

      before, after = runs.map do |queries|
        queries.group_by do |query|
          matches = query.match(EXTRACT_TABLE_RXP)
          next unless matches

          "  #{matches[2]} (#{QUERY_PART_TO_TYPE[matches[1].downcase]})"
        end.transform_values(&:count)
      end

      before.keys.each do |k|
        next if before[k] == after[k]

        msg << "#{k}: #{before[k]} != #{after[k]}\n"
      end

      msg
    end
  end

  # Scale factors to use.
  # Use the smallest possible but representative scale factors by default.
  self.default_scale_factors = [2, 3]

  # Print performed queries if true
  self.verbose = ENV['NPLUSONE_VERBOSE'] == '1'

  # Print table hits difference
  self.show_table_stats = true

  # Ignore matching queries
  self.ignore = /^(BEGIN|COMMIT|SAVEPOINT|RELEASE)/

  # ActiveSupport notifications event to track queries.
  # We track ActiveRecord event by default,
  # but can also track rom-rb events ('sql.rom') as well.
  self.event = 'sql.active_record'
end

require "n_plus_one_control/railtie" if defined?(Rails::Railtie)
