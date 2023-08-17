class RelationshipsController < ApplicationController
  ENTITY_SERVICE = Rails.application.config.entity_service

  def show
    target_entity = ENTITY_SERVICE.find_by_entity_id(params[:entity_id])
    source_entity = resolve_master_entity(ENTITY_SERVICE.find_by_entity_id(params[:id]))

    relationships = InferredRelationshipGraph2
      .new(target_entity)
      .relationships_to(source_entity)

    relationships = RelationshipsSorter.new(relationships)
      .call
      .uniq { |r| r.sourced_relationships.first.keys_for_uniq_grouping }

    raise Mongoid::Errors::DocumentNotFound.new(Relationship, [target_entity.id, source_entity.id]) if relationships.empty?

    reference_number = 0

    relationships.each do |relationship|
      relationship.sourced_relationships.each do |sourced_relationship|
        sourced_relationship[:reference_number] = (reference_number += 1)
      end
    end

    @target_entity = target_entity # decorate(target_entity)
    @source_entity = source_entity # decorate(source_entity)
    @relationships = decorate_with(relationships, InferredRelationshipDecorator)
  end

  def resolve_master_entity(source_entity)
    source_entity.master_entity.presence || source_entity
  end
end
