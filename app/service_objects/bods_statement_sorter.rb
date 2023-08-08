require 'register_sources_bods/enums/statement_types'

class BodsStatementSorter
  # accepts array of statements
  # returns sorted by publication date, with any statements referred to by relationships
  def sort_statements(statements)
    statements = statements.sort_by { |statement| statement.publicationDetails&.publicationDate }

    statements_by_id = statements.map { |statement| [statement.statementID, statement] }.to_h

    used_ids = Set.new
    new_statements = []

    while new_statements.length < statements.length
      current_new_statement_count = new_statements.length
      
      statements.each do |statement|
        next if used_ids.include?(statement.statementID)

        replaced_ids = statement.replacesStatements || []

        dependent_ids =
          case statement.statementType
          when RegisterSourcesBods::StatementTypes['personStatement'], RegisterSourcesBods::StatementTypes['entityStatement']
            []  
          when RegisterSourcesBods::StatementTypes['ownershipOrControlStatement']
            [
              statement.subject&.describedByEntityStatement,
              statement.interestedParty&.describedByEntityStatement,
              statement.interestedParty&.describedByPersonStatement
            ].compact
          end
        
        all_dependent = (replaced_ids + dependent_ids).compact.uniq

        all_dependencies_satisfied = all_dependent.all? { |dependency_id| used_ids.include? dependency_id }

        next unless all_dependencies_satisfied

        new_statements << statement
        used_ids << statement.statementID
      end

      if current_new_statement_count == new_statements.count
        # This only happens when the level limiting means that there are relationship statements
        # without the entity dependency being in this statement list
        # In this scenario, these relationship statements should be skipped, so just stop here
        break
      end
    end

    new_statements
  end
end
