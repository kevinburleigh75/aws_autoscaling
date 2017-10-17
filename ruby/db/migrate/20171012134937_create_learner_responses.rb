class CreateLearnerResponses < ActiveRecord::Migration[5.1]
  def change
    create_table :learner_responses do |t|
      t.uuid     :uuid,           null: false

      t.uuid     :ecosystem_uuid, null: false
      t.uuid     :learner_uuid,   null: false
      t.uuid     :question_uuid,  null: false
      t.uuid     :trial_uuid,     null: false
      t.boolean  :was_correct,    null: false
      t.datetime :responded_at,   null: false

      t.timestamps                null: false
    end

    add_index  :learner_responses,  :uuid,
                                    unique: true
    add_index  :learner_responses,  :learner_uuid
    add_index  :learner_responses,  :question_uuid
    add_index  :learner_responses,  :created_at
  end
end
