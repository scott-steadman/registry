# Arel 2.x (Rails 3.0-3.1) compatibility patch for integer values
# Arel 2.x doesn't handle raw integers in various clauses
# This patches Arel's visitor to wrap integers in Arel nodes

if defined?(Arel::VERSION) && Arel::VERSION =~ /^2\./
  module Arel
    module Visitors
      module IntegerCompatibility
        def visit(o)
          if o.is_a?(Integer)
            super(Arel::Nodes::SqlLiteral.new(o.to_s))
          else
            super
          end
        end
      end

      class ToSql
        prepend IntegerCompatibility
      end

      class DepthFirst
        prepend IntegerCompatibility
      end
    end
  end
end
