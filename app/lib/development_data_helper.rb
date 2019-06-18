module DevelopmentDataHelper
  MODELS = [
    User,
    Submissions::Submission,
    Submissions::Entity,
    Submissions::Relationship,
    Entity,
    Relationship,
    Statement,
    DataSource,
    Import,
    RawDataRecord,
    RawDataProvenance,
  ].freeze
end
