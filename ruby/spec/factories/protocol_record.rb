FactoryBot.define do
  factory :protocol_record do
    group_uuid      { SecureRandom.uuid.to_s }
    instance_uuid   { SecureRandom.uuid.to_s }
    instance_count  { 1 }
    instance_modulo { 0 }
    boss_uuid       { SecureRandom.uuid.to_s }
  end
end
