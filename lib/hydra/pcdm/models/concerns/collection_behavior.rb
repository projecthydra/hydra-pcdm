require 'active_fedora/aggregation'

module Hydra::PCDM
  module CollectionBehavior
    extend ActiveSupport::Concern

    included do
      type RDFVocabularies::PCDMTerms.Collection

      aggregates :members, predicate: RDFVocabularies::PCDMTerms.hasMember,
        class_name: "ActiveFedora::Base"

      indirectly_contains :related_objects, has_member_relation: RDF::Vocab::ORE.aggregates,
        inserted_content_relation: RDF::Vocab::ORE.proxyFor, class_name: "ActiveFedora::Base",
        through: 'ActiveFedora::Aggregation::Proxy', foreign_key: :target

    end

    # behavior:
    #   1) Hydra::PCDM::Collection can aggregate (pcdm:hasMember)  Hydra::PCDM::Collection (no infinite loop, e.g., A -> B -> C -> A)
    #   2) Hydra::PCDM::Collection can aggregate (pcdm:hasMember)  Hydra::PCDM::Object
    #   3) Hydra::PCDM::Collection can aggregate (ore:aggregates)  Hydra::PCDM::Object  (Object related to the Collection)

    #   4) Hydra::PCDM::Collection can NOT aggregate non-PCDM object
    #   5) Hydra::PCDM::Collection can NOT contain (pcdm:hasFile)  Hydra::PCDM::File

    #   6) Hydra::PCDM::Collection can have descriptive metadata
    #   7) Hydra::PCDM::Collection can have access metadata


    def << arg

      # TODO: Not sure how to handle coll1.collections << new_collection.  (see issue #45)
      #       Want to override << on coll1.collections to check that new_work Hydra::PCDM.collection?
      # TODO: Not sure how to handle coll1.objects << new_object.  (see issue #45)
      #       Want to override << on coll1.objects to check that new_work Hydra::PCDM.object?

      # check that arg is an instance of Hydra::PCDM::Collection or Hydra::PCDM::Object
      raise ArgumentError, "argument must be either a pcdm collection or pcdm object" unless
          ( Hydra::PCDM.collection? arg ) || ( Hydra::PCDM.object? arg )
      members << arg
    end

    def collections= collections
      raise ArgumentError, "each collection must be a pcdm collection" unless collections.all? { |c| Hydra::PCDM.collection? c }
      raise ArgumentError, "a collection can't be an ancestor of itself" if collection_ancestor?(collections)
      self.members = self.objects + collections
    end

    def collections
      members.to_a.select { |m| Hydra::PCDM.collection? m }
    end

    def objects= objects
      raise ArgumentError, "each object must be a pcdm object" unless objects.all? { |o| Hydra::PCDM.object? o }
      self.members = self.collections + objects
    end

    def objects
      members.to_a.select { |m| Hydra::PCDM.object? m }
    end

    def collection_ancestor? collections
      collections.each do |check|
        return true if check.id == self.id
        return true if ancestor?(check)
      end
      false
    end

    def ancestor? collection
      return false if collection.collections.empty?
      current_collections = collection.collections
      next_batch = []
      while !current_collections.empty? do
        current_collections.each do |c|
          return true if c.id == self.id
          next_batch += c.collections
        end
        current_collections = next_batch
      end
      false
    end

  end
end

