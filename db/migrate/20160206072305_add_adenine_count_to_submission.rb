class AddAdenineCountToSubmission < ActiveRecord::Migration
  def change
    add_column :submissions, :adenine_count, :decimal
  end
end
