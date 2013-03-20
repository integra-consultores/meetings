class AddIssueIdToMeeting < ActiveRecord::Migration
  def up
    add_column :meetings, :issue_id, :integer
    add_index :meetings, :issue_id
  end
  
  def down
    remove_index :meetings, :issue_id
    remove_column :meetings, :issue_id
  end
end