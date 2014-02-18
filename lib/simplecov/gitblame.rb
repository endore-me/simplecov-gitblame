require 'rugged'
require 'simplecov/gitblame/version'

module SimpleCov
  module Formatter
    class GitblameFormatter
      def format(result)
        result.files.each do |file|
          @repo ||= ::Rugged::Repository.discover(file.filename)
          blame = Blame.new(@repo, file.filename)
          file.coverage.each_with_index do |coverage, line|
            next if coverage.nil?
            committers[blame.for_line(line+1)[:orig_signature][:name]].
              add_file_line(file.filename, line+1, coverage)
          end rescue nil
        end
        committers.each do |name,committer|
          puts sprintf('%s: %.1f%% (%d/%d)', name, committer.coverage, committer.covered, committer.lines)
        end
      end

      def committers
        @committers ||= Hash.new { |h,k| h[k] = Committer.new(k) }
      end

      class Committer < Struct.new :name
        def covered
          files.inject(0) { |s,(_,f)| s + f.count { |a| a.to_i > 0 } }
        end

        def coverage
          covered.to_f/lines * 100
        end

        def worst_file
          files.sort_by { |_,f| -f.count{ |a| a == 0 } }
        end

        def lines
          files.inject(0) { |s,(_,f)| s + f.count { |a| !a.nil? } }
        end

        def add_file_line(filename, line_no, coverage)
          files[filename][line_no] = coverage
        end

        def files
          @files ||= Hash.new { |h,k| h[k] = Array.new }
        end
      end

      class Blame < Struct.new :repo, :file

        def for_line(*args)
          blame && blame.for_line(*args)
        end

        def blame
          @blame ||= ::Rugged::Blame.new(repo, relative_file) rescue nil
        end

        def relative_file
          file.sub("#{repo_directory}/",'')
        end

        def repo_directory
          @repo_directory ||= ::File.dirname(repo.path)
        end

      end
    end
  end
end
