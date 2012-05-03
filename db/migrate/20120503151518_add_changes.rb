class AddChanges < ActiveRecord::Migration
  def up
    add_column :activities, :change_id, :integer
    add_index "activities", ["change_id"], :name => "activities_change_id_index"

    create_table "changes", :force => true do |t|
      t.integer  "user_id"
      t.integer  "idea_id"
      t.integer  "new_idea_id"
      t.string   "type"
      t.string   "status"
      t.integer  "yes_votes",             :default => 0
      t.integer  "no_votes",              :default => 0
      t.datetime "sent_at"
      t.datetime "approved_at"
      t.datetime "declined_at"
      t.text     "content"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "position",              :default => 0
      t.integer  "cost"
      t.integer  "estimated_votes_count", :default => 0
      t.integer  "votes_count",           :default => 0
      t.boolean  "is_endorsers",          :default => true
      t.boolean  "is_opposers",           :default => true
      t.boolean  "is_flip",               :default => false
    end

  add_index "changes", ["new_idea_id"], :name => "changes_new_idea_id_index"
  add_index "changes", ["idea_id"], :name => "changes_idea_id_index"
  add_index "changes", ["status"], :name => "changes_status_index"
  add_index "changes", ["type"], :name => "changes_type_index"
  add_index "changes", ["user_id"], :name => "changes_user_id_index"
  end
end
