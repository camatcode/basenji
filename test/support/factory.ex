defmodule Basenji.Factory do
  @moduledoc false
  use ExMachina.Ecto, repo: Basenji.Repo
  use Basenji.Factory.AccountsFactory
  use Basenji.Factory.ComicFactory
  use Basenji.Factory.CollectionFactory
end
