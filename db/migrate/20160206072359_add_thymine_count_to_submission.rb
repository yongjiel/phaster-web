class AddThymineCountToSubmission < ActiveRecord::Migration
  def change
    add_column :submissions, :thymine_count, :decimal
  end
end
