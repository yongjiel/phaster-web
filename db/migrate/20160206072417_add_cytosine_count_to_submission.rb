class AddCytosineCountToSubmission < ActiveRecord::Migration
  def change
    add_column :submissions, :cytosine_count, :decimal
  end
end
