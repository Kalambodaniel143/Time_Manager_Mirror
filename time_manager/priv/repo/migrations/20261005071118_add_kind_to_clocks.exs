defmodule TimeManager.Repo.Migrations.AddKindToClocks do
  use Ecto.Migration

  def change do
    alter table(:clocks) do
      add :kind, :string
    end

    # Les anciens pointages restent des arrivées ou des départs.
    execute(
      "UPDATE clocks SET kind = CASE WHEN status THEN 'arrival' ELSE 'departure' END",
      "SELECT 1"
    )

    alter table(:clocks) do
      modify :kind, :string, null: false, from: {:string, null: true}
    end

    create constraint(:clocks, :clocks_kind_matches_status,
             check:
               "(status = true AND kind IN ('arrival', 'resume')) OR " <>
                 "(status = false AND kind IN ('departure', 'pause'))"
           )
  end
end
