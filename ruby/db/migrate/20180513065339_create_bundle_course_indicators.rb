class CreateBundleCourseIndicators < ActiveRecord::Migration[5.1]
  def change
    create_table :bundle_course_indicators do |t|
      t.uuid    :indicator_uuid,  null: false
      t.uuid    :course_uuid,     null: false
      t.string  :source,          null: false

      t.boolean :has_been_processed, null: false

      t.timestamps  null: false
    end

    add_index :bundle_course_indicators,  :indicator_uuid,
                                          unique: true

    add_index :bundle_course_indicators, [:course_uuid, :has_been_processed, :created_at],
                                         name: 'index_bcis_on_cu_hbp_ca'

    add_index :bundle_course_indicators, [:has_been_processed, :course_uuid, :created_at],
                                         name: 'index_bcis_on_hbp_cu_ca'

    add_index :bundle_course_indicators, [:created_at, :has_been_processed],
                                         name: 'index_bcis_on_ca_hbp'
  end
end
