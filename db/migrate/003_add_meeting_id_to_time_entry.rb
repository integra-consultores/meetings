class AddMeetingIdToTimeEntry < ActiveRecord::Migration
  def up
    change_table TimeEntry.table_name.to_sym do |t|
      t.references :meeting
      t.index :meeting_id
    end
  end
  
  def down
    remove_index TimeEntry.table_name.to_sym, :meeting_id
    remove_column TimeEntry.table_name.to_sym, :meeting_id
  end
end
