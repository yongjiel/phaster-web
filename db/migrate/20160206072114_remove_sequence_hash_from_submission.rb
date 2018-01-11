class RemoveSequenceHashFromSubmission < ActiveRecord::Migration
  def change
    remove_column :submissions, :sequence_hash, :string
  end
end
