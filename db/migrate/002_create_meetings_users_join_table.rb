class CreateMeetingsUsersJoinTable < ActiveRecord::Migration
  def change
    create_table :meetings_users, :id => false do |t|
      t.references :meeting, :null => false
      t.references :user, :null => false
    end
    add_index :meetings_users, [:meeting_id, :user_id], :unique => true, :name => 'by_meeting_and_user'
  end
end
