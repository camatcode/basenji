defmodule Basenji.Repo.Migrations.AddOptimizationRelationships do
  use Ecto.Migration

  def change do
    # Add indexes for performance (foreign keys already exist)
    create_if_not_exists(index(:comics, [:original_id]))
    create_if_not_exists(index(:comics, [:optimized_id]))

    # Add constraint to prevent optimization chains
    create(
      constraint(:comics, :no_optimization_chain,
        check: "NOT (original_id IS NOT NULL AND optimized_id IS NOT NULL)"
      )
    )
  end
end
