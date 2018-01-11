class AddSequenceLengthToSubmissions < ActiveRecord::Migration
  def change
    add_column :submissions, :sequence_length, :integer
  end
end
