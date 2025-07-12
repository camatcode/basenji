defmodule Basenji.Repo.Migrations.AddOptimizationRelationships do
  use Ecto.Migration

  def change do
    alter table(:comics) do
      add(:original_id, references(:comics, type: :uuid, on_delete: :nilify_all))
      add(:optimized_id, references(:comics, type: :uuid, on_delete: :nilify_all))
    end

    create(index(:comics, [:original_id]))
    create(index(:comics, [:optimized_id]))

    # Add constraint to prevent optimization chains
    create(
      constraint(:comics, :no_optimization_chain,
        check: "NOT (original_id IS NOT NULL AND optimized_id IS NOT NULL)"
      )
    )
  end
end
