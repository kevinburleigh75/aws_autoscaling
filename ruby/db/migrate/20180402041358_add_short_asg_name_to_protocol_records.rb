class AddShortAsgNameToProtocolRecords < ActiveRecord::Migration[5.1]
  def change
    add_column :protocol_records, :asg_short_name, :string
  end
end
