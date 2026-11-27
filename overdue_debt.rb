require "date"

module OverdueDebt
  ID = "overdue-debt"
  MARKER = %r{\A\s*(?://|\#|--)\s*(?:TODO|FIXME)\(debt:\s*(\d{4}-\d{2}-\d{2})\)(?:\s|:|\z)}
  SOURCE_EXTENSIONS = %w[.go .java .js .jsx .kt .py .rb .rs .sh .sql .ts .tsx .yaml .yml].freeze

  def self.scan(files, today:)
    files.flat_map do |path, full_path|
      next [] unless SOURCE_EXTENSIONS.include?(File.extname(path))

      File.foreach(full_path, encoding: "BINARY").with_index(1).filter_map do |line, line_number|
        match = MARKER.match(line)
        next unless match

        begin
          due_on = Date.iso8601(match[1])
        rescue Date::Error
          next
        end
        next unless due_on < today

        {
          rule_id: ID,
          path: path,
          line: line_number,
          due_on: due_on.iso8601,
          message: "Technical debt was due on #{due_on.iso8601}."
        }
      end
    end
  end
end
