class AddGuanineCountToSubmission < ActiveRecord::Migration
  def change
    add_column :submissions, :guanine_count, :decimal
  end
end
