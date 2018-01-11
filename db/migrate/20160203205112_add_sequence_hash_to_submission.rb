class AddSequenceHashToSubmission < ActiveRecord::Migration
  def change
    add_column :submissions, :sequence_hash, :string
  end
end
