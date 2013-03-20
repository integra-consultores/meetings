class CreateMeetings < ActiveRecord::Migration
  def change
    create_table :meetings do |t|
      t.references :author, :null => false
      t.references :project, :null => false
      t.string :subject, :null => false, :limit => 80
      t.text :description
      t.date :date
      t.time :start_hour
      t.time :end_hour
      t.integer :estimated_hours
      t.integer :status
      
      t.timestamps
    end
    add_index :meetings, :author_id
    add_index :meetings, :project_id
  end
end
